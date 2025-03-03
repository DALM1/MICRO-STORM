require 'grpc'
require_relative 'chat_pb'
require_relative 'chat_services_pb'
require_relative './controllers/chat_controller'
require 'time'

class ChatServiceImpl < Chat::ChatService::Service
  def initialize
    @chat_controller = ChatController.new
  end

  def chat(call)
    username = nil
    room = nil
    call.each_remote_read do |chat_msg|
      if username.nil?
        username = chat_msg.sender
        unless @chat_controller.chat_rooms.key?("Main")
          @chat_controller.create_room("Main", nil, username)
        end
        room = @chat_controller.chat_rooms["Main"]
        room.add_client(call, username)
        welcome = Chat::ChatMessage.new(
          sender: "Server",
          content: "Bienvenue #{username} Tapez /help pour la liste des commandes",
          timestamp: Time.now.strftime('%H:%M')
        )
        call.send_msg(welcome)
      else
        @chat_controller.handle_message(call, room, username, chat_msg.content)
      end
    end
  end
end

def main
  port = '0.0.0.0:50051'
  s = GRPC::RpcServer.new
  s.add_http2_port(port, :this_port_is_insecure)
  s.handle(ChatServiceImpl.new)
  puts "⚡️ gRPC Chat server listening on #{port}"
  s.run_till_terminated
end

main
