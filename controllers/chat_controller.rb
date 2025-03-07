require 'pg'
require 'bcrypt'
require_relative '../models/chat_room'
require 'time'
require_relative '../chat_pb'

class ChatController
  attr_accessor :chat_rooms

  def initialize
    @chat_rooms = {}
  end

  def create_room(name, password=nil, creator=nil)
    @chat_rooms[name] = ChatRoom.new(name, password, creator)
  end

  def handle_message(conn, chat_room, username, message)
    if message.start_with?('/')
      handle_command(conn, chat_room, username, message)
    else
      chat_room.broadcast_message(message, username)
    end
  end

  def handle_command(conn, chat_room, username, msg)
    parts = msg.split(' ')
    command = parts[0].downcase

    case command
    when '/help'
      send_text(conn, chat_room.commands)
    when '/list'
      send_text(conn, "Utilisateurs dans ce thread | #{chat_room.list_users}")
    when '/info'
      send_text(conn, "Thread: #{chat_room.name} | Creator: #{chat_room.creator} | Users: #{chat_room.list_users}")
    when '/history'
      chat_room.history.each { |line| send_text(conn, line) }
    when '/banned'
      send_text(conn, "Bannis: #{chat_room.banned_users.join(', ')}")
    when '/cr'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        send_text(conn, "Usage: /cr <nom> <password>")
        return
      end
      create_room(room_name, room_pass, username)
      send_text(conn, "Thread #{room_name} créé.")
      chat_room.remove_client(username)
      new_room = @chat_rooms[room_name]
      new_room.add_client(conn, username)
    when '/cd'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        send_text(conn, "Usage: /cd <nom> <password>")
        return
      end
      if @chat_rooms.key?(room_name)
        chat_room.remove_client(username)
        new_room = @chat_rooms[room_name]
        if new_room.password.nil? || new_room.password == room_pass
          new_room.add_client(conn, username)
        else
          send_text(conn, "⚠️ Mot de passe incorrect pour #{room_name}")
        end
      else
        send_text(conn, "⚠️ Le thread #{room_name} n'existe pas")
      end
    when '/cpd'
      new_password = parts[1]
      if chat_room.creator == username
        chat_room.password = new_password
        send_text(conn, "Mot de passe du thread changé")
      else
        send_text(conn, "⚠️ Seul le créateur peut changer le password")
      end
    when '/ban'
      user_to_ban = parts[1]
      if user_to_ban.nil?
        send_text(conn, "Usage: /ban <pseudo>")
        return
      end
      if chat_room.creator == username
        chat_room.ban_user(user_to_ban)
      else
        send_text(conn, "⚠️ Seul le créateur peut bannir")
      end
    when '/kick'
      user_to_kick = parts[1]
      if user_to_kick.nil?
        send_text(conn, "Usage: /kick <pseudo>")
        return
      end
      if chat_room.creator == username
        chat_room.kick_user(user_to_kick)
      else
        send_text(conn, "⚠️ Seul le créateur peut kick")
      end
    when '/dm'
      user_to_dm = parts[1]
      dm_message = parts[2..-1].join(' ')
      if user_to_dm.nil? || dm_message.empty?
        send_text(conn, "Usage: /dm <pseudo> <message>")
        return
      end
      chat_room.direct_message(username, user_to_dm, dm_message)
    when '/qt'
      send_text(conn, "Commande /qt non implémentée.")
    when '/quit'
      chat_room.remove_client(username)
      conn.close
    when '/color'
      new_color = parts[1]
      if new_color.nil?
        send_text(conn, "Usage: /color <couleur>")
        return
      end
      chat_room.set_color(username, new_color)
      send_text(conn, "Votre couleur est maintenant #{new_color}")
    when '/background'
      bg_url = parts[1]
      if bg_url.nil?
        send_text(conn, "Usage: /background <url>")
        return
      end
      chat_room.broadcast_background(bg_url)
    when '/powerto'
      target = parts[1]
      if target.nil?
        send_text(conn, "Usage: /powerto <pseudo>")
        return
      end
      if chat_room.creator != username
        send_text(conn, "⚠️ Seul le créateur peut donner le role")
        return
      end
      unless chat_room.clients.key?(target)
        send_text(conn, "⚠️ L'utilisateur #{target} n'est pas dans ce thread")
        return
      end
      chat_room.creator = target
      chat_room.broadcast_message("#{username} a donné le rôle de créateur à #{target}", 'Server')
    when '/typo'
      new_font = parts[1]
      if new_font.nil?
        send_text(conn, "Usage: /typo <font_family>")
        return
      end
      special_msg = "CHANGE_FONT|#{new_font}"
      chat_room.broadcast_special(special_msg)
    when '/textcolor'
      new_txt_color = parts[1]
      if new_txt_color.nil?
        send_text(conn, "Usage: /textcolor <couleur>")
        return
      end
      special_msg = "CHANGE_TEXTCOLOR|#{new_txt_color}"
      chat_room.broadcast_special(special_msg)
    when '/register'
      email = parts[1]
      pass  = parts[2]
      new_user = parts[3]
      if email.nil? || pass.nil? || new_user.nil?
        send_text(conn, "Usage: /register <email> <password> <pseudo>")
        return
      end
      register_result = register_account(email, pass, new_user)
      send_text(conn, register_result)
    when '/login'
      email = parts[1]
      pass  = parts[2]
      if email.nil? || pass.nil?
        send_text(conn, "Usage: /login <email> <password>")
        return
      end
      login_result = login_account(email, pass)
      if login_result.start_with?("| Logged in as")
        new_pseudo = login_result.split("as ")[1]
        chat_room.remove_client(username)
        username.replace(new_pseudo)
        chat_room.add_client(conn, username)
      end
      send_text(conn, login_result)
    when '/clear'
      chat_room.history.clear
      chat_room.broadcast_special("CLEAR_LOGS|")
      send_text(conn, "Logs cleared.")
    else
      send_text(conn, "⚠️ Commande inconnue. Tapez /help pour la liste")
    end
  end

  private

  def is_websocket?(conn)
    conn.respond_to?(:text)
  end

  def send_text(conn, text)
    if is_websocket?(conn)
      conn.text(text)
    else
      conn.send_msg(Chat::ChatMessage.new(
        sender: "Server",
        content: text,
        timestamp: Time.now.strftime('%H:%M')
      ))
    end
  end

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
      conn = db_connection
      conn.exec_params("INSERT INTO users (email, username, password_digest) VALUES ($1, $2, $3)", [email, user, pd])
      conn.close
      "| User registered"
    rescue PG::UniqueViolation
      "| Email or username used"
    rescue => ex
      "| Error register: #{ex.message}"
    end
  end

  def login_account(email, password)
    return "| Missing fields" if email.empty? || password.empty?
    begin
      conn = db_connection
      r = conn.exec_params("SELECT * FROM users WHERE email=$1", [email])
      conn.close
      return "| No account" if r.ntuples == 0
      d = r[0]['password_digest']
      u = r[0]['username']
      if BCrypt::Password.new(d) == password
        "| Logged in as #{u}"
      else
        "| Invalid password"
      end
    rescue => ex
      "| Error login: #{ex.message}"
    end
  end
end
