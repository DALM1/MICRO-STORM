def chat_loop(client, chat_room, username)
  client.puts "Welcome to thread '#{chat_room.name}'. Type /help for commands."

  loop do
    begin
      message = client.gets&.chomp
      break if message.nil? || message.downcase == '/quit'

      handle_command(message, client, chat_room, username)
    rescue IOError => e
      puts "⚠️ Erreur de lecture du message : #{e.message}".yellow
      break
    end
  end

  chat_room.remove_client(username)
  client.puts "You have left the thread."
end
