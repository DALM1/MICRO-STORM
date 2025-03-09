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

get '/' do
  content_type :json
  {
    status: "running",
    timestamp: Time.now.to_i,
    upload_path: File.expand_path('public/uploads')
  }.to_json
end

get '/test-upload' do
  content_type :html
  "
  <html>
  <body>
    <h1>Test d'upload</h1>
    <form action='/upload' method='post' enctype='multipart/form-data'>
      <input type='file' name='file'>
      <input type='submit' value='Upload'>
    </form>
  </body>
  </html>
  "
end

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
    "| Error register #{ex.message}"
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

post '/upload' do
  content_type :json

  puts "Démarrage de l'upload de fichier..."

  begin
    unless params[:file] && params[:file][:tempfile] && params[:file][:filename]
      puts "Aucun fichier reçu dans la requête"
      return { success: false, error: "Aucun fichier reçu" }.to_json
    end

    file = params[:file]
    filename = file[:filename]
    tempfile = file[:tempfile]

    puts "Fichier reçu #{filename}, type: #{file[:type]}, taille: #{File.size(tempfile.path)} bytes"

    timestamp = Time.now.to_i
    safe_filename = "#{timestamp}_#{filename.gsub(/[^a-zA-Z0-9\.\-]/, '_')}"

    path = File.join(settings.public_folder, 'uploads', safe_filename)

    FileUtils.cp(tempfile.path, path)
    puts "Fichier enregistré #{path}"

    if File.exist?(path)
      puts "Fichier vérifié et existe dans #{path}"
    else
      puts "ERREUR: Le fichier n'a pas été correctement enregistré dans: #{path}"
    end

    file_url = "http://195.35.1.108:#{request.port}/uploads/#{safe_filename}"

    puts "URL générée pour le fichier #{file_url}"

    response = {
      success: true,
      url: file_url,
      filename: filename,
      type: file[:type] || detect_mime_type(path),
      path: path,
      size: File.size(path)
    }

    puts "Réponse JSON #{response.to_json}"
    return response.to_json

  rescue => e
    puts "ERREUR UPLOAD #{e.message}"
    puts e.backtrace.join("\n")
    { success: false, error: e.message }.to_json
  end
end

get '/check-file' do
  content_type :json

  path = params[:path]

  unless path
    return { success: false, error: "Chemin non spécifié" }.to_json
  end

  begin
    full_path = File.join(settings.public_folder, path)
    exists = File.exist?(full_path)

    {
      success: true,
      path: full_path,
      exists: exists,
      size: exists ? File.size(full_path) : nil,
      readable: exists ? File.readable?(full_path) : false
    }.to_json
  rescue => e
    { success: false, error: e.message }.to_json
  end
end

get '/test-upload-access' do
  content_type :html

  upload_dir = File.join(settings.public_folder, 'uploads')

  unless Dir.exist?(upload_dir)
    return "Le dossier d'uploads n'existe pas #{upload_dir}"
  end

  files = Dir.entries(upload_dir).reject { |f| f == '.' || f == '..' }

  if files.empty?
    return "Aucun fichier dans le dossier d'uploads."
  end

  html = <<-HTML
  <html>
  <head>
    <title>Test des fichiers uploadés</title>
    <style>
      body { font-family: sans-serif; margin: 20px; }
      .file-entry { margin: 10px 0; padding: 10px; border: 1px solid #ccc; }
      img { max-width: 300px; max-height: 200px; }
    </style>
  </head>
  <body>
    <h1>Fichiers uploadés (#{files.size})</h1>
    <div>Chemin complet: #{File.expand_path(upload_dir)}</div>
    <div>URL de base: http://195.35.1.108:#{request.port}/uploads/</div>
    <hr>
  HTML

  files.each do |filename|
    file_path = File.join(upload_dir, filename)
    file_url = "http://195.35.1.108:#{request.port}/uploads/#{filename}"
    file_size = File.size(file_path) rescue 'Inconnu'
    file_type = File.extname(filename).downcase

    html += <<-HTML
    <div class="file-entry">
      <div><strong>Nom:</strong> #{filename}</div>
      <div><strong>Taille:</strong> #{file_size} bytes</div>
      <div><strong>URL:</strong> <a href="#{file_url}" target="_blank">#{file_url}</a></div>
      <div><strong>Test d'accessibilité:</strong>
    HTML

    if ['.jpg', '.jpeg', '.png', '.gif', '.webp'].include?(file_type)
      html += <<-HTML
        <img src="#{file_url}" alt="Prévisualisation">
      HTML
    end

    html += <<-HTML
      </div>
    </div>
    HTML
  end

  html += "</body></html>"

  return html
end

def detect_mime_type(file_path)
  extension = File.extname(file_path).downcase
  case extension
  when '.jpg', '.jpeg'
    'image/jpeg'
  when '.png'
    'image/png'
  when '.gif'
    'image/gif'
  when '.pdf'
    'application/pdf'
  when '.doc', '.docx'
    'application/msword'
  when '.xls', '.xlsx'
    'application/vnd.ms-excel'
  when '.zip'
    'application/zip'
  when '.mp3'
    'audio/mpeg'
  when '.mp4'
    'video/mp4'
  else
    'application/octet-stream'
  end
end
