package chat

import (
	"database/sql"
	"fmt"
	"log"
	"regexp"
	"strings"
	"sync"
	"time"
)

type Connection interface {
	Send(text string) error
}

type ChatRoom struct {
	Name         string
	Password     string
	Creator      string
	Clients      map[string]Connection // clé: username
	History      []string
	BannedUsers  []string
	ClientColors map[string]string
	Mutex        sync.Mutex
	DB           *sql.DB
}

func NewChatRoom(name, password, creator string, db *sql.DB) *ChatRoom {
	room := &ChatRoom{
		Name:         name,
		Password:     password,
		Creator:      creator,
		Clients:      make(map[string]Connection),
		History:      []string{},
		BannedUsers:  []string{},
		ClientColors: make(map[string]string),
		DB:           db,
	}
	room.ensureMessagesTable()
	return room
}

func (r *ChatRoom) ensureMessagesTable() {
	query := `
	CREATE TABLE IF NOT EXISTS messages (
		id SERIAL PRIMARY KEY,
		sender TEXT,
		content TEXT,
		timestamp TEXT
	);`
	_, err := r.DB.Exec(query)
	if err != nil {
		log.Printf("Error creating messages table: %v", err)
	}
}

func (r *ChatRoom) persistMessage(sender, content, timestamp string) {
	_, err := r.DB.Exec("INSERT INTO messages (sender, content, timestamp) VALUES ($1, $2, $3)", sender, content, timestamp)
	if err != nil {
		log.Printf("Error persisting message: %v", err)
	}
}

func (r *ChatRoom) AddClient(conn Connection, username string) {
	r.Mutex.Lock()
	defer r.Mutex.Unlock()
	for _, banned := range r.BannedUsers {
		if banned == username {
			conn.Send("⚠️ Vous êtes banni de ce thread")
			return
		}
	}
	r.Clients[username] = conn
	r.BroadcastMessage(fmt.Sprintf("%s joined the thread", username), "Server")
}

func (r *ChatRoom) RemoveClient(username string) {
	r.Mutex.Lock()
	defer r.Mutex.Unlock()
	delete(r.Clients, username)
	r.BroadcastMessage(fmt.Sprintf("%s left the thread", username), "Server")
}

func (r *ChatRoom) BanUser(username string) {
	r.RemoveClient(username)
	r.BannedUsers = append(r.BannedUsers, username)
	r.BroadcastMessage(fmt.Sprintf("%s a été banni", username), "Server")
}

func (r *ChatRoom) KickUser(username string) {
	r.RemoveClient(username)
	r.BroadcastMessage(fmt.Sprintf("%s a été expulsé", username), "Server")
}

func (r *ChatRoom) DirectMessage(sender, recipient, message string) {
	if conn, ok := r.Clients[recipient]; ok {
		conn.Send(fmt.Sprintf("W (private) | %s | %s", sender, message))
	} else if conn, ok := r.Clients[sender]; ok {
		conn.Send(fmt.Sprintf("⚠️ L'utilisateur %s n'est pas dans ce thread", recipient))
	}
}

func (r *ChatRoom) SetColor(username, color string) {
	r.ClientColors[username] = color
}

func (r *ChatRoom) BroadcastMessage(message, sender string) {
	r.Mutex.Lock()
	defer r.Mutex.Unlock()
	timestamp := time.Now().Format("15:04")
	color := r.ClientColors[sender]
	if color == "" {
		color = "#FFFFFF"
	}
	formatted := fmt.Sprintf("[%s] <span style='color: %s'>%s</span> %s", timestamp, color, sender, r.linkify(message))
	r.History = append(r.History, formatted)
	r.persistMessage(sender, message, timestamp)
	for _, conn := range r.Clients {
		conn.Send(formatted)
	}
}

func (r *ChatRoom) BroadcastBackground(url string) {
	r.BroadcastSpecial("CHANGE_BG|" + url)
}

func (r *ChatRoom) BroadcastSpecial(msg string) {
	for _, conn := range r.Clients {
		conn.Send(msg)
	}
}

func (r *ChatRoom) ListUsers() string {
	users := []string{}
	for u := range r.Clients {
		users = append(users, u)
	}
	return strings.Join(users, ", ")
}

func (r *ChatRoom) linkify(text string) string {
	re := regexp.MustCompile(`(https?://\S+)`)
	return re.ReplaceAllStringFunc(text, func(url string) string {
		lower := strings.ToLower(url)
		if strings.HasSuffix(lower, ".jpg") || strings.HasSuffix(lower, ".jpeg") ||
			strings.HasSuffix(lower, ".png") || strings.HasSuffix(lower, ".gif") {
			return fmt.Sprintf(`<a href="%s" target="_blank"><img src="%s" alt="Image" style="max-width:200px;"/></a>`, url, url)
		}
		return fmt.Sprintf(`<a href="%s" target="_blank">%s</a>`, url, url)
	})
}
