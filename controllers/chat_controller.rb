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
      return nil # Pas de changement de salle
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

    when '/register'
      email = parts[1]
      pass  = parts[2]
      new_user = parts[3]
      if email.nil? || pass.nil? || new_user.nil?
        driver.text("Usage: /register <email> <password> <pseudo>")
        return nil
      end
      register_result = register_account(email, pass, new_user)
      driver.text(register_result)

    when '/login'
      email = parts[1]
      pass  = parts[2]
      if email.nil? || pass.nil?
        driver.text("Usage: /login <email> <password>")
        return nil
      end
      login_result = login_account(email, pass)
      if login_result.start_with?("| Logged in as")
        new_pseudo = login_result.split("as ")[1]
        chat_room.remove_client(username)
        chat_room.add_client(driver, new_pseudo)
        if username.is_a?(String) && username.respond_to?(:replace)
          username.replace(new_pseudo)
        end
      end
      driver.text(login_result)

    when '/cpd'
      new_password = parts[1]
      if chat_room.creator == username
        chat_room.password = new_password
        driver.text("Mot de passe du thread changé")
      else
        driver.text("⚠️ Seul le créateur peut changer le password")
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
