package chat

import (
	"database/sql"
	"sync"
)

type ChatController struct {
	Rooms map[string]*ChatRoom
	Mutex sync.Mutex
	DB    *sql.DB
}

func NewChatController(db *sql.DB) *ChatController {
	return &ChatController{
		Rooms: make(map[string]*ChatRoom),
		DB:    db,
	}
}

func (c *ChatController) CreateRoom(name, password, creator string) {
	c.Mutex.Lock()
	defer c.Mutex.Unlock()
	room := NewChatRoom(name, password, creator, c.DB)
	c.Rooms[name] = room
}

func (c *ChatController) GetRoom(name string) *ChatRoom {
	c.Mutex.Lock()
	defer c.Mutex.Unlock()
	return c.Rooms[name]
}
