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
  end

  def add_client(driver, username)
    if @banned_users.include?(username)
      driver.text("⚠️ Vous êtes banni de ce thread")
      return
    end
    @clients[username] = driver
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
      @clients[recipient].text("W (private) | #{sender}] | #{message}")
    else
      @clients[sender].text("⚠️ L'utilisateur #{recipient} n'est pas dans ce thread")
    end
  end

  def set_color(username, color)
    @client_colors[username] = color
  end

  # -----------------------------
  # Envoi de message à tous
  # Timestamp raccourci en HH:MM
  # -----------------------------
  def broadcast_message(message, sender)
    timestamp = Time.now.strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'
    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{message}"
    @history << formatted_message
    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts "⚠️ Erreur d'envoi de message | #{e.message}".yellow
      end
    end
  end

  # -----------------------------
  # Commande pour changer le BG
  # -----------------------------
  def broadcast_background(url)
    special_msg = "CHANGE_BG|#{url}"
    broadcast_special(special_msg)
  end

  # -----------------------------
  # Commandes spéciales : /typo, /textcolor
  # -----------------------------
  def broadcast_special(msg)
    @clients.each_value do |driver|
      begin
        driver.text(msg)
      rescue IOError => e
        puts "⚠️ #{e.message}".yellow
      end
    end
  end

  def list_users
    @clients.keys.join(', ')
  end

  # -----------------------------
  # Liste des commandes
  # -----------------------------
  def commands
    <<~CMD
      Commandes disponibles :
      /help                        - Afficher cette aide
      /list                        - Liste des utilisateurs
      /info                        - Infos sur ce thread
      /history                     - Afficher l'historique
      /banned                      - Voir les bannis
      /cr <nom> <pass>             - Créer un nouveau thread (et y basculer)
      /cd <nom> <pass>             - Changer de thread
      /cpd <pass>                  - Changer le password du thread
      /ban <pseudo>                - Bannir un utilisateur
      /kick <pseudo>               - Kick un utilisateur
      /dm <pseudo> <msg>           - Message privé
      /color <couleur>             - Changer la couleur de votre pseudo
      /background <url>            - Changer le background (pour tout le monde)
      /powerto <pseudo>            - Donner le rôle de créateur
      /typo <font_family>          - Changer la police de tout le chat
      /textcolor <couleur>         - Changer la couleur de tout le texte
      /register <email> <pass> <pseudo> - Créer un compte
      /login <email> <pass>        - Se connecter
      /quit                        - Quitter
    CMD
  end
end
