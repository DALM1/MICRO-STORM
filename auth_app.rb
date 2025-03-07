require 'sinatra'
require 'sqlite3'
require 'bcrypt'

set :bind, '0.0.0.0'
set :port, 4567

def db_connection
  SQLite3::Database.new "auth.db", results_as_hash: true
end

begin
  db = db_connection
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      username TEXT UNIQUE NOT NULL,
      password_digest TEXT NOT NULL
    );
  SQL
  db.close
rescue => e
  puts "Error creating table: #{e}"
end

post '/register' do
  e = params[:email].to_s.strip
  p1 = params[:password].to_s
  u = params[:username].to_s.strip
  return "| Missing fields" if e.empty? || p1.empty? || u.empty?
  pd = BCrypt::Password.create(p1)
  begin
    db = db_connection
    db.execute("INSERT INTO users (email, username, password_digest) VALUES (?, ?, ?)", [e, u, pd])
    "| User registered"
  rescue SQLite3::ConstraintException
    "| Email or username used"
  rescue => ex
    "| Error register: #{ex.message}"
  end
end

post '/login' do
  e = params[:email].to_s.strip
  p1 = params[:password].to_s
  return "| Missing fields" if e.empty? || p1.empty?
  begin
    db = db_connection
    row = db.get_first_row("SELECT * FROM users WHERE email = ?", [e])
    return "| No account" if row.nil?
    if BCrypt::Password.new(row['password_digest']) == p1
      "| Logged in as #{row['username']}"
    else
      "| Invalid password"
    end
  rescue => ex
    "| Error login: #{ex.message}"
  end
end
