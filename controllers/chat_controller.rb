require 'sqlite3'
require 'bcrypt'
require_relative '../models/chat_room'

class ChatController
  attr_accessor :chat_rooms

  COLOR_NAMES = {
    "red" => "#FF0000",
    "green" => "#008000",
    "blue" => "#0000FF",
    "yellow" => "#FFFF00",
    "orange" => "#FFA500",
    "purple" => "#800080",
    "pink" => "#FFC0CB",
    "black" => "#000000",
    "white" => "#FFFFFF",
    "gray" => "#808080",
    "grey" => "#808080",
    "brown" => "#A52A2A",
    "cyan" => "#00FFFF",
    "magenta" => "#FF00FF",
    "lime" => "#00FF00",
    "navy" => "#000080",
    "teal" => "#008080",
    "olive" => "#808000",
    "maroon" => "#800000",
    "silver" => "#C0C0C0",
    "gold" => "#FFD700",
    "indigo" => "#4B0082",
    "violet" => "#EE82EE",
    "turquoise" => "#40E0D0",
    "crimson" => "#DC143C",
    "salmon" => "#FA8072",
    "coral" => "#FF7F50",
    "tomato" => "#FF6347",
    "skyblue" => "#87CEEB",
    "steelblue" => "#4682B4",
    "royalblue" => "#4169E1",
    "darkgreen" => "#006400",
    "forestgreen" => "#228B22",
    "seagreen" => "#2E8B57",
    "darkred" => "#8B0000"
  }

  def initialize
    @chat_rooms = {}
    setup_database
  end

  def setup_database
    begin
      db = db_connection
      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE NOT NULL,
          username TEXT UNIQUE NOT NULL,
          password_digest TEXT NOT NULL
        );
      SQL

      db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS user_preferences (
          user_id INTEGER PRIMARY KEY,
          text_color TEXT,
          background_url TEXT,
          font_family TEXT,
          color TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id)
        );
      SQL
      db.close
    rescue => ex
      puts "Erreur lors de l'initialisation de la base de données #{ex.message}"
    end
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

  def convert_color(color_input)
    return color_input if color_input.start_with?('#')

    color_name = color_input.downcase

    if COLOR_NAMES.key?(color_name)
      return COLOR_NAMES[color_name]
    end

    return color_input
  end

  def handle_command(msg, driver, chat_room, username)
    parts   = msg.split(' ')
    command = parts[0].downcase
    new_room = nil

    case command
    when '/help'
      driver.text(chat_room.commands)
      driver.text("Pour les commandes /color et /textcolor, vous pouvez utiliser les noms de couleurs (ex: /color red) ou les codes hexadécimaux (ex: /color #FF0000).")

    when '/list'
      driver.text("Utilisateurs dans ce thread | #{chat_room.list_users}")

    when '/info'
      driver.text("Thread | #{chat_room.name} | creator #{chat_room.creator} | users #{chat_room.list_users}")

    when '/history'
      chat_room.history.each { |line| driver.text(line) }

    when '/banned'
      driver.text("Bannis | #{chat_room.banned_users.join(', ')}")

    when '/cr'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage /cr <nom> <password>")
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
        driver.text("Usage /cd <nom> <password>")
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
        driver.text("Usage /ban <pseudo>")
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
        driver.text("Usage /kick <pseudo>")
        return nil
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
        driver.text("Usage /dm <pseudo> <message>")
        return nil
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
        driver.text("Usage /color <couleur> (nom de couleur ou code hexadécimal)")
        return nil
      end

      hex_color = convert_color(new_color)

      chat_room.set_color(username, hex_color)
      driver.text("Votre couleur est maintenant #{new_color} (#{hex_color})")

      save_user_preference(username, 'color', hex_color)

    when '/background'
      bg_url = parts[1]
      if bg_url.nil?
        driver.text("Usage: /background <url>")
        return nil
      end
      chat_room.broadcast_background(bg_url)

      save_user_preference(username, 'background_url', bg_url)

    when '/music'
      music_url = parts[1]
      if music_url.nil?
        driver.text("Usage /music <url>")
        return nil
      end

      if chat_room.password.nil?
        driver.text("⚠️ La musique ne peut être utilisée que dans les threads privés")
        return nil
      end

      chat_room.broadcast_message("#{username} a partagé de la musique [/playmusic pour écouter]", 'Server')

      chat_room.current_music_url = music_url
      chat_room.current_music_user = username

      driver.text("Musique partagée. Les utilisateurs peuvent l'écouter avec /playmusic")

    when '/playmusic'
      if !chat_room.respond_to?(:current_music_url) || chat_room.current_music_url.nil?
        driver.text("⚠️ Aucune musique n'a été partagée dans ce thread")
        return nil
      end

      special_msg = "PLAY_MUSIC|#{chat_room.current_music_url}"
      driver.special(special_msg)
      driver.text("Lecture de la musique partagée par #{chat_room.current_music_user}")

    when '/stopmusic'
      special_msg = "STOP_MUSIC|"
      driver.special(special_msg)
      driver.text("Lecture de la musique arrêtée")

    when '/volume'
      volume_level = parts[1]
      if volume_level.nil?
        driver.text("Usage /volume <niveau> (0-100)")
        return nil
      end

      begin
        volume = Integer(volume_level)
        if volume < 0 || volume > 100
          driver.text("⚠️ Le volume doit être entre 0 et 100")
          return nil
        end

        special_msg = "SET_VOLUME|#{volume}"
        driver.special(special_msg)
        driver.text("Volume réglé à #{volume}%")
      rescue ArgumentError
        driver.text("⚠️ Le volume doit être un nombre entre 0 et 100")
      end

    when '/powerto'
      target = parts[1]
      if target.nil?
        driver.text("Usage /powerto <pseudo>")
        return nil
      end
      if chat_room.creator != username
        driver.text("⚠️ Seul le créateur peut donner le role")
        return nil
      end
      unless chat_room.clients.key?(target)
        driver.text("⚠️ L'utilisateur #{target} n'est pas dans ce thread")
        return nil
      end
      chat_room.creator = target
      chat_room.broadcast_message("#{username} a donné le rôle de créateur à #{target}", 'Server')

    when '/typo'
      new_font = parts[1]
      if new_font.nil?
        driver.text("Usage /typo <font_family>")
        return nil
      end
      special_msg = "CHANGE_FONT|#{new_font}"
      chat_room.broadcast_special(special_msg)

      save_user_preference(username, 'font_family', new_font)

    when '/textcolor'
      new_txt_color = parts[1]
      if new_txt_color.nil?
        driver.text("Usage /textcolor <couleur> (nom de couleur ou code hexadécimal)")
        return nil
      end

      hex_color = convert_color(new_txt_color)

      special_msg = "CHANGE_TEXTCOLOR|#{hex_color}"
      chat_room.broadcast_special(special_msg)

      driver.text("Couleur du texte changée en #{new_txt_color} (#{hex_color})")

      save_user_preference(username, 'text_color', hex_color)

    when '/register'
      email = parts[1]
      pass  = parts[2]
      new_user = parts[3]
      if email.nil? || pass.nil? || new_user.nil?
        driver.text("Usage /register <email> <password> <pseudo>")
        return nil
      end
      register_result = register_account(email, pass, new_user)
      driver.text(register_result)

    when '/login'
      email = parts[1]
      pass  = parts[2]
      if email.nil? || pass.nil?
        driver.text("Usage /login <email> <password>")
        return nil
      end
      login_result = login_account(email, pass)
      if login_result.start_with?("| Logged in as")
        new_pseudo = login_result.split("as ")[1]

        chat_room.remove_client(username)

        chat_room.add_client(driver, username)

        if username.is_a?(String) && username.respond_to?(:replace)
          username.replace(new_pseudo)
        end

        apply_user_preferences(driver, chat_room, new_pseudo)
      end
      driver.text(login_result)

    when '/clear'
      chat_room.history.clear
      chat_room.broadcast_special("CLEAR_LOGS|")
      driver.text("|| Logs cleared.")
      driver.text("|| ⚠️ Connected to WS server")

    when '/savepref'
      driver.text("Sauvegarde de vos préférences en cours...")
      save_all_preferences(username, chat_room)
      driver.text("Préférences sauvegardées avec succès!")

    when '/listcolors'
      color_list = COLOR_NAMES.keys.sort.join(", ")
      driver.text("Noms de couleurs disponibles: #{color_list}")

    else
      driver.text("⚠️ Commande inconnue. Tapez /help pour la liste")
    end

    return new_room
  end

  private

  def db_connection
    db_path = ENV['DB_PATH'] || 'chat_app.db'
    SQLite3::Database.new(db_path)
  end

  def register_account(email, password, user)
    return "| Missing fields" if email.empty? || password.empty? || user.empty?
    pd = BCrypt::Password.create(password)
    begin
      db = db_connection
      db.execute("INSERT INTO users (email, username, password_digest) VALUES (?, ?, ?)", [email, user, pd])
      user_id = db.last_insert_row_id
      db.execute("INSERT INTO user_preferences (user_id) VALUES (?)", [user_id])
      db.close
      "| User registered"
    rescue SQLite3::ConstraintException => e
      "| Email or username used"
    rescue => ex
      "| Error #{ex.message}"
    end
  end

  def login_account(email, password)
    return "| Missing fields" if email.empty? || password.empty?
    begin
      db = db_connection
      result = db.execute("SELECT * FROM users WHERE email=?", [email])
      db.close
      return "| No account" if result.empty?

      user_data = result[0]
      password_digest = user_data[3]
      username = user_data[2]

      if BCrypt::Password.new(password_digest) == password
        "| Logged in as #{username}"
      else
        "| Invalid password"
      end
    rescue => ex
      "| Error #{ex.message}"
    end
  end

  def get_user_id(username)
    begin
      db = db_connection
      result = db.execute("SELECT id FROM users WHERE username=?", [username])
      db.close
      return result.empty? ? nil : result[0][0]
    rescue => ex
      puts "Erreur lors de la récupération de l'ID utilisateur: #{ex.message}"
      return nil
    end
  end

  def save_user_preference(username, preference_key, preference_value)
    user_id = get_user_id(username)
    return false unless user_id

    begin
      db = db_connection
      result = db.execute("SELECT user_id FROM user_preferences WHERE user_id=?", [user_id])

      if result.empty?
        db.execute("INSERT INTO user_preferences (user_id, #{preference_key}) VALUES (?, ?)",
                  [user_id, preference_value])
      else
        db.execute("UPDATE user_preferences SET #{preference_key}=? WHERE user_id=?",
                  [preference_value, user_id])
      end
      db.close
      return true
    rescue => ex
      puts "Erreur lors de la sauvegarde des préférences: #{ex.message}"
      return false
    end
  end

  def save_all_preferences(username, chat_room)
    user_color = chat_room.get_user_color(username)

    save_user_preference(username, 'color', user_color) if user_color
  end

  def apply_user_preferences(driver, chat_room, username)
    user_id = get_user_id(username)
    return unless user_id

    begin
      db = db_connection
      result = db.execute("SELECT text_color, background_url, font_family, color FROM user_preferences WHERE user_id=?", [user_id])
      db.close

      if !result.empty?
        prefs = result[0]
        text_color = prefs[0]
        bg_url = prefs[1]
        font = prefs[2]
        color = prefs[3]

        if text_color
          special_msg = "CHANGE_TEXTCOLOR|#{text_color}"
          chat_room.broadcast_special(special_msg)
          driver.text("Couleur de texte restaurée: #{text_color}")
        end

        if bg_url
          chat_room.broadcast_background(bg_url)
          driver.text("Arrière-plan restauré")
        end

        if font
          special_msg = "CHANGE_FONT|#{font}"
          chat_room.broadcast_special(special_msg)
          driver.text("Police restaurée: #{font}")
        end

        if color
          chat_room.set_color(username, color)
          driver.text("Couleur de pseudo restaurée: #{color}")
        end

        driver.text("| Préférences utilisateur restaurées")
      end
    rescue => ex
      puts "Erreur lors de l'application des préférences: #{ex.message}"
    end
  end
end
