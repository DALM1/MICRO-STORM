class ChatRoom
  attr_accessor :name, :password, :clients, :creator, :history, :banned_users

  def initialize(name, password = nil, creator = nil)
    @name = name
    @password = password
    @clients = {}
    @history = []
    @creator = creator
    @banned_users = []
  end

  def add_client(client, username)
    if @banned_users.include?(username)
      client.puts "⚠️ You are banned from this thread."
      return
    end

    @clients[username] = client
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
    broadcast_message("#{username} has been banned.", 'Server')
  end

  def kick_user(username)
    remove_client(username)
    broadcast_message("#{username} has been kicked out of the thread.", 'Server')
  end

  def direct_message(sender, recipient, message)
    if @clients.key?(recipient)
      @clients[recipient].puts "[DM from #{sender}]: #{message}"
    else
      @clients[sender].puts "⚠️ User #{recipient} is not in the thread."
    end
  end

  def broadcast_message(message, sender)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    formatted_message = "[#{timestamp}] #{sender}: #{message}"
    @history << formatted_message
    @clients.each_value do |client|
      begin
        client.puts formatted_message if client
      rescue IOError => e
        puts "⚠️ Erreur d'envoi de message : #{e.message}".yellow
      end
    end
  end

  def list_users
    @clients.keys.join(', ')
  end

  def commands
    <<~COMMANDS
      Available commands:
      - /help: Show available commands
      - /list: List users in the thread
      - /history: Show message history
      - /banned: Show banned users
      - /cr <name> <password>: Create a new thread
      - /cd <name> <password>: Switch to another thread
      - /cpd <password>: Change thread password
      - /ban <username>: Ban a user
      - /kick <username>: Kick a user
      - /dm <username> <message>: Send a direct message
      - /qt <username> <command>: Execute a command remotely
    COMMANDS
  end
end
