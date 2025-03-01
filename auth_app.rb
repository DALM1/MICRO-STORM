require 'sinatra'
require 'pg'
require 'bcrypt'

set :bind, '0.0.0.0'
set :port, 4567

def db_connection
  PG.connect(dbname: ENV['DB_NAME'], user: ENV['DB_USER'], password: ENV['DB_PASS'], host: ENV['DB_HOST'])
end

begin
  c = db_connection
  c.exec("CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, email TEXT UNIQUE NOT NULL, username TEXT UNIQUE NOT NULL, password_digest TEXT NOT NULL)")
  c.close
rescue
end

post '/register' do
  e = params[:email].to_s.strip
  p1 = params[:password].to_s
  u = params[:username].to_s.strip
  return "| Missing fields" if e.empty? || p1.empty? || u.empty?
  pd = BCrypt::Password.create(p1)
  begin
    c = db_connection
    c.exec_params("INSERT INTO users (email, username, password_digest) VALUES ($1, $2, $3)", [e, u, pd])
    c.close
    "| User registered"
  rescue PG::UniqueViolation
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
    c = db_connection
    r = c.exec_params("SELECT * FROM users WHERE email=$1", [e])
    c.close
    return "| No account" if r.ntuples == 0
    d = r[0]['password_digest']
    if BCrypt::Password.new(d) == p1
      "| Logged in as #{r[0]['username']}"
    else
      "| Invalid password"
    end
  rescue => ex
    "| Error login: #{ex.message}"
  end
end
