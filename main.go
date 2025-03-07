package main

import (
	"log"
	"sync"

	"storm/auth"
	"storm/wsserver"
	"storm/grpcserver"
)

func main() {
	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		log.Println("Starting Auth server on :4567")
		auth.StartAuthServer(":4567")
	}()

	go func() {
		defer wg.Done()
		log.Println("Starting WebSocket server on :3630")
		wsserver.StartWSServer(":3630")
	}()

	go func() {
		defer wg.Done()
		log.Println("Starting gRPC server on :50051")
		grpcserver.StartGRPCServer(":50051")
	}()

	wg.Wait()
}
