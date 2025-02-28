require 'socket'
require 'colorize'
require 'websocket/driver'
require_relative './controllers/chat_controller'

server_ip   = '0.0.0.0'
server_port = 3630
server      = TCPServer.new(server_ip, server_port)
chat_controller = ChatController.new

puts "⚡️ Serveur WebSocket en cours d'exécution sur #{server_ip}:#{server_port}".green

loop do
  socket = server.accept

  Thread.new do
    begin
      driver = WebSocket::Driver.server(socket)

      driver.on(:connect) do
        if driver.env['HTTP_UPGRADE'].to_s.downcase != 'websocket'
          puts "🔴 Requête invalide - Pas de WebSocket".red
          socket.close
        else
          driver.start
        end
      end

      driver.on(:open) do
        puts "🟢 Connexion WebSocket ouverte".green
        driver.text("Entrez votre pseudo :")
      end

      username     = nil
      current_room = nil

      driver.on(:message) do |event|
        msg = event.data.strip

        if username.nil?
          username = msg
          if username.empty?
            driver.text("⚠️ Pseudo vide, réessayez.")
            next
          end

          unless chat_controller.chat_rooms.key?("Main")
            chat_controller.create_room("Main", nil, "Server")
          end

          current_room = chat_controller.chat_rooms["Main"]
          current_room.add_client(driver, username)
          driver.text("Bienvenue #{username}! Tapez /help pour la liste des commandes.")
          next
        end

        chat_controller.handle_message(driver, current_room, username, msg)
      end

      driver.on(:close) do
        puts "🔴 Connexion WebSocket fermée".red
        current_room.remove_client(username) if current_room && username
        socket.close
      end

      begin
        while (data = socket.readpartial(1024))
          driver.parse(data)
        end
      rescue EOFError
      end

    rescue => e
      puts "⚠️ Erreur de connexion : #{e.message}".red
    ensure
      socket.close unless socket.closed?
    end
  end
end
