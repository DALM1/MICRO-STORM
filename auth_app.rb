require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'fileutils'

set :bind, '0.0.0.0'
set :port, 4567

DB_FILE = "auth.db"

def db_connection
  SQLite3::Database.new(DB_FILE)
end

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

FileUtils.mkdir_p('public/uploads')

post '/register' do
  e = params[:email].to_s.strip
  p1 = params[:password].to_s
  u = params[:username].to_s.strip

  return "| Missing fields" if e.empty? || p1.empty? || u.empty?

  pd = BCrypt::Password.create(p1)
  begin
    db = db_connection
    db.execute("INSERT INTO users (email, username, password_digest) VALUES (?, ?, ?)", [e, u, pd])
    db.close
    "| User registered"
  rescue SQLite3::ConstraintException
    "| Email or username already used"
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
    r = db.execute("SELECT username, password_digest FROM users WHERE email = ?", [e])
    db.close

    return "| No account" if r.empty?

    u, d = r.first
    if BCrypt::Password.new(d) == p1
      "| Logged in as #{u}"
    else
      "| Invalid password"
    end
  rescue => ex
    "| Error login: #{ex.message}"
  end
end

post '/upload' do
  content_type :json

  unless params[:file] && params[:file][:tempfile] && params[:file][:filename]
    return { success: false, error: "Aucun fichier reçu" }.to_json
  end

  file = params[:file]
  filename = file[:filename]
  tempfile = file[:tempfile]

  timestamp = Time.now.to_i
  safe_filename = "#{timestamp}_#{filename.gsub(/[^a-zA-Z0-9\.\-]/, '_')}"

  path = "public/uploads/#{safe_filename}"

  begin
    FileUtils.cp(tempfile.path, path)

    file_url = "#{request.base_url}/uploads/#{safe_filename}"

    { success: true, url: file_url }.to_json
  rescue => e
    { success: false, error: e.message }.to_json
  end
end
