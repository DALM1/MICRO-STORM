require 'sqlite3'
require 'bcrypt'
require_relative '../models/chat_room'

class ChatController
  attr_accessor :chat_rooms

  def initialize
    @chat_rooms = {}
  end

  def create_room(name, password=nil, creator=nil)
    @chat_rooms[name] = ChatRoom.new(name, password, creator.is_a?(String) ? creator.dup : creator)
    return @chat_rooms[name]
  end

  def handle_message(driver, chat_room, username, message)
    if message.start_with?('/')
      return handle_command(message, driver, chat_room, username)
    else
      chat_room.broadcast_message(message, username)
      return nil
    end
  end

  def handle_command(msg, driver, chat_room, username)
    parts   = msg.split(' ')
    command = parts[0].downcase
    new_room = nil

    case command
    when '/help'
      driver.text(chat_room.commands)

    when '/list'
      driver.text("Utilisateurs dans ce thread | #{chat_room.list_users}")

    when '/info'
      driver.text("Thread | #{chat_room.name} | creator: #{chat_room.creator} | users: #{chat_room.list_users}")

    when '/history'
      chat_room.history.each { |line| driver.text(line) }

    when '/banned'
      driver.text("Bannis: #{chat_room.banned_users.join(', ')}")

    when '/cr'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage: /cr <nom> <password>")
        return nil
      end
      new_room = create_room(room_name, room_pass, username)
      driver.text("Thread #{room_name} créé.")
      chat_room.remove_client(username)
      new_room.add_client(driver, username)
      return new_room

    when '/cd'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage: /cd <nom> <password>")
        return nil
      end
      if @chat_rooms.key?(room_name)
        new_room = @chat_rooms[room_name]
        if new_room.password.nil? || new_room.password == room_pass
          chat_room.remove_client(username)
          if new_room.add_client(driver, username)
            return new_room
          end
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
        return nil
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
        return nil
      end
      if chat_room.creator == username
        chat_room.kick_user(user_to_kick)
      else
        driver.text("⚠️ Seul le créateur peut kick")
      end

    when '/clear'
      chat_room.history.clear
      chat_room.broadcast_special("CLEAR_LOGS|")
      driver.text("|| Logs cleared.")
      driver.text("|| ⚠️ Connected to WS server")

    else
      driver.text("⚠️ Commande inconnue. Tapez /help pour la liste")
    end
    return new_room
  end

  private

  DB_FILE = "auth.db"

  def db_connection
    SQLite3::Database.new(DB_FILE)
  end

  def register_account(email, password, user)
    return "| Missing fields" if email.empty? || password.empty? || user.empty?
    pd = BCrypt::Password.create(password)
    begin
      c = db_connection
      c.execute("INSERT INTO users (email, username, password_digest) VALUES (?, ?, ?)", [email, user, pd])
      c.close
      "| User registered"
    rescue SQLite3::ConstraintException
      "| Email or username already used"
    rescue => ex
      "| Error #{ex.message}"
    end
  end

  def login_account(email, password)
    return "| Missing fields" if email.empty? || password.empty?
    begin
      c = db_connection
      r = c.execute("SELECT username, password_digest FROM users WHERE email = ?", [email])
      c.close
      return "| No account" if r.empty?
      u, d = r.first
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
