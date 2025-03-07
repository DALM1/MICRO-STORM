package wsserver

import (
	"database/sql"
	"log"
	"net/http"
	"sync"

	"github.com/gorilla/websocket"
	_ "github.com/lib/pq"
	"storm/chat"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type WSConnection struct {
	Conn  *websocket.Conn
	Mutex sync.Mutex
}

func (w *WSConnection) Send(text string) error {
	w.Mutex.Lock()
	defer w.Mutex.Unlock()
	return w.Conn.WriteMessage(websocket.TextMessage, []byte(text))
}

var controller *chat.ChatController
var once sync.Once

func initController() {
	// DSN pour PostgreSQL, à adapter
	dsn := "postgres://pguser:pgpassword@localhost/messages_db?sslmode=disable"
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	controller = chat.NewChatController(db)
	controller.CreateRoom("Main", "", "Server")
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
	once.Do(initController)
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Upgrade error: %v", err)
		return
	}
	wsConn := &WSConnection{Conn: conn}
	// Lire le pseudo en première ligne
	_, msg, err := conn.ReadMessage()
	if err != nil {
		log.Printf("Error reading username: %v", err)
		conn.Close()
		return
	}
	username := string(msg)
	if username == "" {
		conn.WriteMessage(websocket.TextMessage, []byte("⚠️ Pseudo vide, réessayez"))
		conn.Close()
		return
	}
	room := controller.GetRoom("Main")
	room.AddClient(wsConn, username)
	wsConn.Send("Bienvenue " + username + " Tapez /help pour la liste des commandes")
	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			log.Printf("Error reading message: %v", err)
			room.RemoveClient(username)
			break
		}
		room.BroadcastMessage(string(message), username)
	}
}

func StartWSServer(addr string) {
	http.HandleFunc("/ws", wsHandler)
	log.Fatal(http.ListenAndServe(addr, nil))
}
