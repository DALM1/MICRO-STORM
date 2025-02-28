class ChatRoom
  attr_accessor :name, :password, :clients, :creator, :history, :banned_users

  def initialize(name, password=nil, creator=nil)
    @name         = name
    @password     = password
    @creator      = creator
    @clients      = {} # { username => driver }
    @history      = []
    @banned_users = []
  end

  def add_client(driver, username)
    if @banned_users.include?(username)
      driver.text("⚠️ Vous êtes banni de ce thread.")
      return
    end
    @clients[username] = driver
    broadcast_message("#{username} joined the thread.", 'Server')
  end

  def remove_client(username)
    if @clients.key?(username)
      @clients.delete(username)
      broadcast_message("#{username} left the thread.", 'Server')
    end
  end

  def ban_user(username)
    remove_client(username)
    @banned_users << username
    broadcast_message("#{username} a été banni.", 'Server')
  end

  def kick_user(username)
    remove_client(username)
    broadcast_message("#{username} a été expulsé du thread.", 'Server')
  end

  def direct_message(sender, recipient, message)
    if @clients.key?(recipient)
      @clients[recipient].text("[DM de #{sender}] : #{message}")
    else
      @clients[sender].text("⚠️ L'utilisateur #{recipient} n'est pas dans ce thread.")
    end
  end

  def broadcast_message(message, sender)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    formatted_message = "[#{timestamp}] #{sender}: #{message}"
    @history << formatted_message

    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts "⚠️ Erreur d'envoi de message : #{e.message}".yellow
      end
    end
  end

  def list_users
    @clients.keys.join(', ')
  end

  def commands
    <<~CMD
      Commandes disponibles :
      /help               - Afficher cette aide
      /list               - Liste des utilisateurs
      /history            - Afficher l'historique
      /banned             - Voir les bannis
      /cr <nom> <pass>    - Créer un nouveau thread
      /cd <nom> <pass>    - Changer de thread
      /cpd <pass>         - Changer le password du thread
      /ban <pseudo>       - Bannir un utilisateur
      /kick <pseudo>      - Kick un utilisateur
      /dm <pseudo> <msg>  - Message privé
      /quit               - Quitter
    CMD
  end
end
