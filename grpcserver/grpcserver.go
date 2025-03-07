package grpcserver

import (
	"database/sql"
	"log"
	"net"
	"time"

	pb "storm/chatpb"
	"storm/chat"

	_ "github.com/lib/pq"
	"google.golang.org/grpc"
)

type grpcConnection struct {
	stream pb.ChatService_ChatServer
}

func (g *grpcConnection) Send(text string) error {
	msg := &pb.ChatMessage{
		Sender:    "Server",
		Content:   text,
		Timestamp: time.Now().Format("15:04"),
	}
	return g.stream.Send(msg)
}

type chatServiceServer struct {
	pb.UnimplementedChatServiceServer
	controller *chat.ChatController
}

func (s *chatServiceServer) Chat(stream pb.ChatService_ChatServer) error {
	var username string
	room := s.controller.GetRoom("Main")
	conn := &grpcConnection{stream: stream}
	for {
		in, err := stream.Recv()
		if err != nil {
			return err
		}
		if username == "" {
			username = in.Sender
			room.AddClient(conn, username)
			welcome := &pb.ChatMessage{
				Sender:    "Server",
				Content:   "Bienvenue " + username + " Tapez /help pour la liste des commandes",
				Timestamp: time.Now().Format("15:04"),
			}
			stream.Send(welcome)
		} else {
			room.BroadcastMessage(in.Content, username)
		}
	}
}

func StartGRPCServer(addr string) {
	dsn := "postgres://pguser:pgpassword@localhost/messages_db?sslmode=disable"
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	controller := chat.NewChatController(db)
	controller.CreateRoom("Main", "", "Server")

	lis, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterChatServiceServer(s, &chatServiceServer{controller: controller})
	log.Printf("gRPC server listening on %s", addr)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
