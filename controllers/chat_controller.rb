require 'pg'
require 'bcrypt'
require_relative '../models/chat_room'

class ChatController
  attr_accessor :chat_rooms

  def initialize
    @chat_rooms = {}
  end

  def create_room(name, password=nil, creator=nil)
    @chat_rooms[name] = ChatRoom.new(name, password, creator)
  end

  def handle_message(driver, chat_room, username, message)
    if message.start_with?('/')
      handle_command(message, driver, chat_room, username)
    else
      chat_room.broadcast_message(message, username)
    end
  end

  def handle_command(msg, driver, chat_room, username)
    parts   = msg.split(' ')
    command = parts[0].downcase

    case command
    when '/help'
      driver.text(chat_room.commands)

    when '/list'
      driver.text("Utilisateurs dans ce thread | #{chat_room.list_users}")

    when '/info'
      driver.text("Thread : #{chat_room.name} | Creator : #{chat_room.creator} | Users : #{chat_room.list_users}")

    when '/history'
      chat_room.history.each { |line| driver.text(line) }

    when '/banned'
      driver.text("Bannis : #{chat_room.banned_users.join(', ')}")

    when '/cr'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage: /cr <nom> <password>")
        return
      end
      create_room(room_name, room_pass, username)
      driver.text("Thread #{room_name} créé.")
      chat_room.remove_client(username)
      new_room = @chat_rooms[room_name]
      new_room.add_client(driver, username)

    when '/cd'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage: /cd <nom> <password>")
        return
      end
      if @chat_rooms.key?(room_name)
        chat_room.remove_client(username)
        new_room = @chat_rooms[room_name]
        if new_room.password.nil? || new_room.password == room_pass
          new_room.add_client(driver, username)
        else
          driver.text("⚠️ Mot de passe incorrect pour #{room_name}")
        end
      else
        driver.text("⚠️ Le thread #{room_name} n'existe pas")
      end

    when '/cpd'
      new_password = parts[1]
      if chat_room.creator == username
        chat_room.password = new_password
        driver.text("Mot de passe du thread changé")
      else
        driver.text("⚠️ Seul le créateur peut changer le password")
      end

    when '/ban'
      user_to_ban = parts[1]
      if user_to_ban.nil?
        driver.text("Usage: /ban <pseudo>")
        return
      end
      if chat_room.creator == username
        chat_room.ban_user(user_to_ban)
      else
        driver.text("⚠️ Seul le créateur peut bannir")
      end

    when '/kick'
      user_to_kick = parts[1]
      if user_to_kick.nil?
        driver.text("Usage: /kick <pseudo>")
        return
      end
      if chat_room.creator == username
        chat_room.kick_user(user_to_kick)
      else
        driver.text("⚠️ Seul le créateur peut kick")
      end

    when '/dm'
      user_to_dm = parts[1]
      dm_message = parts[2..-1].join(' ')
      if user_to_dm.nil? || dm_message.empty?
        driver.text("Usage: /dm <pseudo> <message>")
        return
      end
      chat_room.direct_message(username, user_to_dm, dm_message)

    when '/qt'
      driver.text("Commande /qt non implémentée.")

    when '/quit'
      chat_room.remove_client(username)
      driver.close

    when '/color'
      new_color = parts[1]
      if new_color.nil?
        driver.text("Usage: /color <couleur>")
        return
      end
      chat_room.set_color(username, new_color)
      driver.text("Votre couleur est maintenant #{new_color}")

    when '/background'
      bg_url = parts[1]
      if bg_url.nil?
        driver.text("Usage: /background <url>")
        return
      end
      chat_room.broadcast_background(bg_url)

    when '/powerto'
      target = parts[1]
      if target.nil?
        driver.text("Usage: /powerto <pseudo>")
        return
      end
      if chat_room.creator != username
        driver.text("⚠️ Seul le créateur peut donner le role")
        return
      end
      unless chat_room.clients.key?(target)
        driver.text("⚠️ L'utilisateur #{target} n'est pas dans ce thread")
        return
      end
      chat_room.creator = target
      chat_room.broadcast_message("#{username} a donné le rôle de créateur à #{target}", 'Server')

    when '/typo'
      new_font = parts[1]
      if new_font.nil?
        driver.text("Usage: /typo <font_family>")
        return
      end
      special_msg = "CHANGE_FONT|#{new_font}"
      chat_room.broadcast_special(special_msg)

    when '/textcolor'
      new_txt_color = parts[1]
      if new_txt_color.nil?
        driver.text("Usage: /textcolor <couleur>")
        return
      end
      special_msg = "CHANGE_TEXTCOLOR|#{new_txt_color}"
      chat_room.broadcast_special(special_msg)

    when '/register'
      email = parts[1]
      pass  = parts[2]
      new_user = parts[3]
      if email.nil? || pass.nil? || new_user.nil?
        driver.text("Usage: /register <email> <password> <pseudo>")
        return
      end
      register_result = register_account(email, pass, new_user)
      driver.text(register_result)

    when '/login'
      email = parts[1]
      pass  = parts[2]
      if email.nil? || pass.nil?
        driver.text("Usage: /login <email> <password>")
        return
      end
      login_result = login_account(email, pass)
      if login_result.start_with?("| Logged in as")
        new_pseudo = login_result.split("as ")[1]
        chat_room.remove_client(username)
        username.replace(new_pseudo)
        chat_room.add_client(driver, username)
      end
      driver.text(login_result)

    # -----------------------------
    # Nouveau : /clear
    # -----------------------------
    when '/clear'
      chat_room.history.clear
      # Envoyer un message spécial au front
      chat_room.broadcast_special("CLEAR_LOGS|")
      driver.text("Logs cleared.")

    else
      driver.text("⚠️ Commande inconnue. Tapez /help pour la liste")
    end
  end

  private

  def db_connection
    PG.connect(
      dbname: ENV['DB_NAME'],
      user: ENV['DB_USER'],
      password: ENV['DB_PASS'],
      host: ENV['DB_HOST']
    )
  end

  def register_account(email, password, user)
    return "| Missing fields" if email.empty? || password.empty? || user.empty?
    pd = BCrypt::Password.create(password)
    begin
      c = db_connection
      c.exec_params("INSERT INTO users (email, username, password_digest) VALUES ($1, $2, $3)", [email, user, pd])
      c.close
      "| User registered"
    rescue PG::UniqueViolation
      "| Email or username used"
    rescue => ex
      "| Error #{ex.message}"
    end
  end

  def login_account(email, password)
    return "| Missing fields" if email.empty? || password.empty?
    begin
      c = db_connection
      r = c.exec_params("SELECT * FROM users WHERE email=$1", [email])
      c.close
      return "| No account" if r.ntuples == 0
      d = r[0]['password_digest']
      u = r[0]['username']
      if BCrypt::Password.new(d) == password
        "| Logged in as #{u}"
      else
        "| Invalid password"
      end
    rescue => ex
      "| Error #{ex.message}"
    end
  end
end
