require_relative '../models/chat_room'

class ChatController
  attr_accessor :chat_rooms

  def initialize
    @chat_rooms = {}
  end

  def create_room(name, password=nil, creator=nil)
    @chat_rooms[name] = ChatRoom.new(name, password, creator)
  end

  def handle_message(driver, chat_room, username, message)
    if message.start_with?('/')
      handle_command(message, driver, chat_room, username)
    else
      chat_room.broadcast_message(message, username)
    end
  end

  private

  def handle_command(msg, driver, chat_room, username)
    parts   = msg.split(' ')
    command = parts[0].downcase

    case command
    when '/help'
      driver.text(chat_room.commands)

    when '/list'
      driver.text("Utilisateurs dans ce thread : #{chat_room.list_users}")

    when '/history'
      chat_room.history.each { |line| driver.text(line) }

    when '/banned'
      driver.text("Bannis : #{chat_room.banned_users.join(', ')}")

    when '/cr'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage: /cr <nom> <password>")
        return
      end
      create_room(room_name, room_pass, username)
      driver.text("Thread #{room_name} créé.")

    when '/cd'
      room_name = parts[1]
      room_pass = parts[2]
      if room_name.nil?
        driver.text("Usage: /cd <nom> <password>")
        return
      end
      if @chat_rooms.key?(room_name)
        chat_room.remove_client(username)
        new_room = @chat_rooms[room_name]
        if new_room.password.nil? || new_room.password == room_pass
          new_room.add_client(driver, username)
        else
          driver.text("⚠️ Mot de passe incorrect pour #{room_name}")
        end
      else
        driver.text("⚠️ Le thread #{room_name} n'existe pas.")
      end

    when '/cpd'
      new_password = parts[1]
      if chat_room.creator == username
        chat_room.password = new_password
        driver.text("Mot de passe du thread changé.")
      else
        driver.text("⚠️ Seul le créateur peut changer le password.")
      end

    when '/ban'
      user_to_ban = parts[1]
      if user_to_ban.nil?
        driver.text("Usage: /ban <pseudo>")
        return
      end
      if chat_room.creator == username
        chat_room.ban_user(user_to_ban)
      else
        driver.text("⚠️ Seul le créateur peut bannir.")
      end

    when '/kick'
      user_to_kick = parts[1]
      if user_to_kick.nil?
        driver.text("Usage: /kick <pseudo>")
        return
      end
      if chat_room.creator == username
        chat_room.kick_user(user_to_kick)
      else
        driver.text("⚠️ Seul le créateur peut kick.")
      end

    when '/dm'
      user_to_dm = parts[1]
      dm_message = parts[2..-1].join(' ')
      if user_to_dm.nil? || dm_message.empty?
        driver.text("Usage: /dm <pseudo> <message>")
        return
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
        driver.text("Usage: /color <couleur>")
        return
      end
      chat_room.set_color(username, new_color)
      driver.text("Votre couleur est maintenant #{new_color}")

    when '/background'
      bg_url = parts[1]
      if bg_url.nil?
        driver.text("Usage: /background <url>")
        return
      end
      chat_room.broadcast_background(bg_url)

    else
      driver.text("⚠️ Commande inconnue. Tapez /help pour la liste.")
    end
  end
end
