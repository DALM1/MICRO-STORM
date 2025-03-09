require 'sinatra'
require 'sqlite3'
require 'bcrypt'
require 'fileutils'
require 'json'

# Configuration du serveur
set :bind, '0.0.0.0'
set :port, 4567

# Activer les logs de débogage
enable :logging

# Configuration CORS
before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'

  if request.request_method == 'OPTIONS'
    halt 200
  end

  # Log de débogage
  puts "#{request.request_method} #{request.path_info} - Params: #{params.inspect}"
end

# Gestionnaire d'erreurs
error do |e|
  puts "ERREUR: #{e.message}"
  puts e.backtrace.join("\n")
  content_type :json
  { success: false, error: e.message }.to_json
end

# Configuration de la base de données
DB_FILE = "auth.db"

def db_connection
  SQLite3::Database.new(DB_FILE)
end

# Initialisation de la base de données
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

# Créer un dossier pour les uploads s'il n'existe pas
FileUtils.mkdir_p('public/uploads')
puts "Dossier d'upload créé: public/uploads"

# S'assurer que le dossier a les bonnes permissions
begin
  FileUtils.chmod(0755, 'public/uploads')
  puts "Permissions du dossier d'upload mises à jour: 755"
rescue => e
  puts "Avertissement: impossible de modifier les permissions du dossier: #{e.message}"
end

# Configuration pour servir les fichiers statiques
set :public_folder, File.dirname(__FILE__) + '/public'

# Page d'accueil pour tester le serveur
get '/' do
  content_type :json
  {
    status: "running",
    timestamp: Time.now.to_i,
    upload_path: File.expand_path('public/uploads')
  }.to_json
end

# Page de test d'upload simple
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

    puts "Fichier reçu: #{filename}, type: #{file[:type]}, taille: #{File.size(tempfile.path)} bytes"

    timestamp = Time.now.to_i
    safe_filename = "#{timestamp}_#{filename.gsub(/[^a-zA-Z0-9\.\-]/, '_')}"

    path = File.join(settings.public_folder, 'uploads', safe_filename)

    FileUtils.cp(tempfile.path, path)
    puts "Fichier enregistré: #{path}"

    if File.exist?(path)
      puts "Fichier vérifié et existe dans: #{path}"
    else
      puts "ERREUR: Le fichier n'a pas été correctement enregistré dans: #{path}"
    end

    file_url = "http://#{request.host}:#{request.port}/uploads/#{safe_filename}"

    puts "URL générée pour le fichier: #{file_url}"

    response = {
      success: true,
      url: file_url,
      filename: filename,
      path: path,
      size: File.size(path)
    }

    puts "Réponse JSON: #{response.to_json}"
    return response.to_json

  rescue => e
    puts "ERREUR UPLOAD: #{e.message}"
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
