require 'socket'
require 'colorize'
require 'websocket/driver'
require_relative './controllers/chat_controller'

server_ip = '0.0.0.0'
server_port = 3630
server = TCPServer.new(server_ip, server_port)
chat_controller = ChatController.new

puts "⚡️ Serveur WebSocket en cours d'exécution sur #{server_ip}:#{server_port}".green

loop do
  Thread.start(server.accept) do |client|
    begin
      driver = WebSocket::Driver.server(client)

      driver.on(:connect) do |event|
        if driver.headers['Upgrade'].downcase != 'websocket'
          puts "🔴 Requête invalide - Pas de WebSocket".red
          client.close
        else
          driver.start
        end
      end

      driver.on(:open) do |event|
        puts "🟢 Connexion ouverte".green
        client.puts "Entrez votre pseudo :"
      end

      driver.on(:message) do |event|
        message = event.data.chomp
        if message.empty?
          client.puts "Message vide, veuillez réessayer."
          next
        end

        if !client.closed?
          chat_controller.create_room("Main", nil, "Server") unless chat_controller.chat_rooms.key?("Main")
          chat_controller.chat_rooms["Main"].add_client(client, message)
          chat_controller.chat_loop(client, chat_controller.chat_rooms["Main"], message)
        else
          puts "🔴 Connexion fermée par le client."
        end
      end

      driver.on(:close) do |event|
        puts "🔴 Connexion fermée".red
        client.close
      end

      while client && !client.closed?
        data = client.readpartial(1024)
        driver.parse(data)
      end
    rescue => e
      puts "⚠️ Erreur de connexion : #{e.message}".red
    ensure
      client.close unless client.closed?
    end
  end
end
