require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'fileutils'
require 'json'

set :bind, '0.0.0.0'
set :port, 4567

enable :logging

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'

  if request.request_method == 'OPTIONS'
    halt 200
  end

  puts "#{request.request_method} #{request.path_info} - Params: #{params.inspect}"
end

error do |e|
  puts "ERREUR: #{e.message}"
  puts e.backtrace.join("\n")
  content_type :json
  { success: false, error: e.message }.to_json
end

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
puts "Dossier d'upload créé: public/uploads"

begin
  FileUtils.chmod(0755, 'public/uploads')
  puts "Permissions du dossier d'upload mises à jour: 755"
rescue => e
  puts "Avertissement: impossible de modifier les permissions du dossier: #{e.message}"
end

set :public_folder, File.dirname(__FILE__) + '/public'

post '/register' do
  content_type :text

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
  content_type :text

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

get '/' do
  content_type :json
  { status: "running", timestamp: Time.now.to_i }.to_json
end

post '/upload' do
  content_type :json

  begin
    unless params[:file] && params[:file][:tempfile] && params[:file][:filename]
      return { success: false, error: "Aucun fichier reçu" }.to_json
    end

    file = params[:file]
    filename = file[:filename]
    tempfile = file[:tempfile]

    puts "Fichier reçu: #{filename}, taille: #{File.size(tempfile.path)} bytes"

    timestamp = Time.now.to_i
    safe_filename = "#{timestamp}_#{filename.gsub(/[^a-zA-Z0-9\.\-]/, '_')}"

    path = "public/uploads/#{safe_filename}"

    FileUtils.cp(tempfile.path, path)
    puts "Fichier enregistré: #{path}"

    file_url = "http://195.35.1.108:4567/uploads/#{safe_filename}"

    {
      success: true,
      url: file_url,
      filename: filename,
      size: File.size(path)
    }.to_json
  rescue => e
    puts "ERREUR UPLOAD: #{e.message}"
    puts e.backtrace.join("\n")
    { success: false, error: e.message }.to_json
  end
end
