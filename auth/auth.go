package auth

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

var db *sql.DB

func init() {
	var err error
	db, err = sql.Open("sqlite3", "./auth.db")
	if err != nil {
		log.Fatal(err)
	}
	createTable := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		email TEXT UNIQUE NOT NULL,
		username TEXT UNIQUE NOT NULL,
		password_digest TEXT NOT NULL
	);`
	_, err = db.Exec(createTable)
	if err != nil {
		log.Fatal(err)
	}
}

type Response struct {
	Message string `json:"message"`
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	email := r.FormValue("email")
	password := r.FormValue("password")
	username := r.FormValue("username")
	if email == "" || password == "" || username == "" {
		json.NewEncoder(w).Encode(Response{"Missing fields"})
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		json.NewEncoder(w).Encode(Response{"Error: " + err.Error()})
		return
	}
	_, err = db.Exec("INSERT INTO users (email, username, password_digest) VALUES (?, ?, ?)", email, username, string(hash))
	if err != nil {
		json.NewEncoder(w).Encode(Response{"Email or username used"})
		return
	}
	json.NewEncoder(w).Encode(Response{"User registered"})
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	email := r.FormValue("email")
	password := r.FormValue("password")
	if email == "" || password == "" {
		json.NewEncoder(w).Encode(Response{"Missing fields"})
		return
	}
	var id int
	var username, passwordDigest string
	err := db.QueryRow("SELECT id, username, password_digest FROM users WHERE email = ?", email).Scan(&id, &username, &passwordDigest)
	if err != nil {
		json.NewEncoder(w).Encode(Response{"No account"})
		return
	}
	err = bcrypt.CompareHashAndPassword([]byte(passwordDigest), []byte(password))
	if err != nil {
		json.NewEncoder(w).Encode(Response{"Invalid password"})
		return
	}
	json.NewEncoder(w).Encode(Response{"Logged in as " + username})
}

func StartAuthServer(addr string) {
	http.HandleFunc("/register", registerHandler)
	http.HandleFunc("/login", loginHandler)
	log.Fatal(http.ListenAndServe(addr, nil))
}
