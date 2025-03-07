require 'pg'
require 'time'

class ChatRoom
  attr_accessor :name, :password, :clients, :creator, :history, :banned_users, :client_colors

  def initialize(name, password=nil, creator=nil)
    @name = name
    @password = password
    @creator = creator
    @clients = {}
    @history = []
    @banned_users = []
    @client_colors = {}
    ensure_messages_table
  end

  def ensure_messages_table
    begin
      conn = PG.connect(dbname: ENV['MSG_DB_NAME'], user: ENV['MSG_DB_USER'], password: ENV['MSG_DB_PASS'], host: ENV['MSG_DB_HOST'])
      conn.exec <<-SQL
        CREATE TABLE IF NOT EXISTS messages (
          id SERIAL PRIMARY KEY,
          sender TEXT,
          content TEXT,
          timestamp TEXT
        );
      SQL
      conn.close
    rescue => ex
      puts "Error creating messages table: #{ex.message}"
    end
  end

  def add_client(conn, username)
    if @banned_users.include?(username)
      send_msg(conn, "⚠️ Vous êtes banni de ce thread")
      return
    end
    @clients[username] = conn
    broadcast_message("#{username} joined the thread", 'Server')
  end

  def remove_client(username)
    if @clients.key?(username)
      @clients.delete(username)
      broadcast_message("#{username} left the thread", 'Server')
    end
  end

  def ban_user(username)
    remove_client(username)
    @banned_users << username
    broadcast_message("#{username} a été banni", 'Server')
  end

  def kick_user(username)
    remove_client(username)
    broadcast_message("#{username} a été expulsé du thread", 'Server')
  end

  def direct_message(sender, recipient, message)
    if @clients.key?(recipient)
      send_msg(@clients[recipient], "W (private) | #{sender}] | #{message}")
    else
      send_msg(@clients[sender], "⚠️ L'utilisateur #{recipient} n'est pas dans ce thread")
    end
  end

  def set_color(username, color)
    @client_colors[username] = color
  end

  def broadcast_message(message, sender)
    timestamp = Time.now.strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'
    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{linkify(message)}"
    @history << formatted_message
    persist_message(message, sender, timestamp)
    @clients.each_value do |conn|
      send_msg(conn, formatted_message)
    end
  end

  def persist_message(message, sender, timestamp)
    begin
      conn = PG.connect(dbname: ENV['MSG_DB_NAME'], user: ENV['MSG_DB_USER'], password: ENV['MSG_DB_PASS'], host: ENV['MSG_DB_HOST'])
      conn.exec_params("INSERT INTO messages (sender, content, timestamp) VALUES ($1, $2, $3)", [sender, message, timestamp])
      conn.close
    rescue => ex
      puts "Error persisting message: #{ex.message}"
    end
  end

  def broadcast_background(url)
    broadcast_special("CHANGE_BG|#{url}")
  end

  def broadcast_special(msg)
    @clients.each_value do |conn|
      send_msg(conn, msg)
    end
  end

  def list_users
    @clients.keys.join(', ')
  end

  def commands
    lines = [
      "/help                        - Afficher cette aide",
      "/list                        - Liste des utilisateurs",
      "/info                        - Infos sur ce thread",
      "/history                     - Afficher l'historique",
      "/banned                      - Voir les bannis",
      "/cr <nom> <pass>             - Créer un nouveau thread (et y basculer)",
      "/cd <nom> <pass>             - Changer de thread",
      "/cpd <pass>                  - Changer le password du thread",
      "/ban <pseudo>                - Bannir un utilisateur",
      "/kick <pseudo>               - Kick un utilisateur",
      "/dm <pseudo> <msg>           - Message privé",
      "/color <couleur>             - Changer la couleur de votre pseudo",
      "/background <url>            - Changer le background (pour tout le monde)",
      "/powerto <pseudo>            - Donner le rôle de créateur",
      "/typo <font_family>          - Changer la police de tout le chat",
      "/textcolor <couleur>         - Changer la couleur de tout le texte",
      "/register <email> <pass> <pseudo> - Créer un compte",
      "/login <email> <pass>        - Se connecter",
      "/clear                       - Effacer l'historique",
      "/quit                        - Quitter"
    ]
    lines.map { |line| "$ #{line}" }.join("\n")
  end

  private

  def is_websocket?(conn)
    conn.respond_to?(:text)
  end

  def send_msg(conn, text)
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

  def linkify(text)
    text.gsub(%r{(https?://\S+)}) do |url|
      if url =~ /\.(jpg|jpeg|png|gif)\b/i
        %Q{<a href="#{url}" target="_blank"><img src="#{url}" alt="Image" style="max-width:200px;"/></a>}
      else
        %Q{<a href="#{url}" target="_blank">#{url}</a>}
      end
    end
  end
end
