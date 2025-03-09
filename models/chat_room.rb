class ChatRoom
  attr_accessor :name, :password, :clients, :creator, :history, :banned_users, :client_colors
  attr_accessor :current_music_url, :current_music_user

  def initialize(name, password=nil, creator=nil)
    @name = name
    @password = password
    @creator = creator
    @clients = {}
    @history = []
    @banned_users = []
    @client_colors = {}
    @current_music_url = nil
    @current_music_user = nil
  end

  def add_client(driver, username)
    if @banned_users.include?(username)
      driver.text("⚠️ Vous êtes banni de ce thread")
      return false
    end
    @clients[username] = driver
    broadcast_message("#{username} joined the thread", 'Server')
    return true
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
      @clients[sender].text("W (private) to #{recipient} | #{message}")
    else
      @clients[sender].text("⚠️ L'utilisateur #{recipient} n'est pas dans ce thread")
    end
  end

  def set_color(username, color)
    @client_colors[username] = color
  end

  def get_user_color(username)
    @client_colors[username]
  end

  def broadcast_message(message, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'
    message = escape_html(message)

    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{message}"
    @history << formatted_message

    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts "⚠️ Erreur d'envoi de message | #{e.message}"
      end
    end
  end

  def broadcast_image(image_url, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'

    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> <img src=\"#{image_url}\" alt=\"image\" style=\"max-width: 500px; max-height: 400px;\">"
    @history << formatted_message

    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts "⚠️ Erreur d'envoi d'image | #{e.message}"
      end
    end
  end

  def broadcast_formatted_message(html_content, sender)
    timestamp = (Time.now + 3600).strftime('%H:%M')
    color = @client_colors[sender] || '#FFFFFF'

    formatted_message = "[#{timestamp}] <span style='color: #{color}'>#{sender}</span> #{html_content}"
    @history << formatted_message

    @clients.each_value do |driver|
      begin
        driver.text(formatted_message)
      rescue IOError => e
        puts "⚠️ Erreur d'envoi de message formaté | #{e.message}"
      end
    end
  end

  def clear_chat(driver)
    driver.text("CLEAR_LOGS|")
  end

  def broadcast_background(url)
    broadcast_special("CHANGE_BG|#{url}")
  end

  def broadcast_special(msg)
    @clients.each_value do |driver|
      begin
        driver.special(msg)
      rescue IOError => e
        puts "⚠️ #{e.message}"
      end
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
      "/music <url>                 - Partager de la musique (threads privés uniquement)",
      "/playmusic                   - Écouter la musique partagée",
      "/stopmusic                   - Arrêter la lecture de la musique",
      "/volume <niveau>             - Régler le volume (0-100)",
      "/image <url>                 - Partager une image via son URL",
      "/file <url> [nom]            - Partager un fichier via son URL",
      "/upload                      - Envoyer un fichier (tout format)",
      "/powerto <pseudo>            - Donner le rôle de créateur",
      "/typo <font_family>          - Changer la police de tout le chat",
      "/textcolor <couleur>         - Changer la couleur de tout le texte",
      "/register <email> <pass> <pseudo> - Créer un compte",
      "/login <email> <pass>        - Se connecter",
      "/clear                       - Effacer l'historique",
      "/listcolors                  - Afficher la liste des noms de couleurs disponibles",
      "/savepref                    - Sauvegarder vos préférences",
      "/quit                        - Quitter"
    ]

    lines.map { |line| " #{line}" }.join("\n")
  end

  private

  def escape_html(text)
    text.to_s.gsub(/[&<>"]/) { |match| {'&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;'}[match] }
  end
end
