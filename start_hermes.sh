#!/bin/bash

cd /root/MICRO-STORM

docker rm -f hermes_container 2>/dev/null

cat > Gemfile << EOL
source 'https://rubygems.org'
gem 'sqlite3'
gem 'sinatra', '~> 3.0'
gem 'bcrypt'
gem 'colorize'
gem 'websocket-driver'
gem 'webrick'
gem 'rack'
EOL

bundle install

mkdir -p uploads

docker build -t hermes .

docker run -d --name hermes_container \
  -p 3630:3630 \
  -p 4567:4567 \
  -v $(pwd)/uploads:/app/public/uploads \
  -e DB_NAME=hermes \
  -e DB_USER=user \
  -e DB_PASS=admin \
  -e DB_HOST=localhost \
  hermes

echo "Démarrage des services..."
sleep 2
docker logs hermes_container

echo "Services démarrés. Ports ouverts:"
echo "- WebSocket: 3630"
echo "- HTTP (uploads): 4567"
echo "Dossier des uploads monté dans: $(pwd)/uploads"

if docker ps | grep -q hermes_container; then
  echo "🟢 Le conteneur fonctionne correctement."
else
  echo "🔴 Le conteneur s'est arrêté. Vérifiez les logs pour plus de détails:"
  docker logs hermes_container

  echo "Tentative de démarrage sans le serveur d'upload..."
  cat > Dockerfile.ws << EOL
FROM ruby:3.2

WORKDIR /app

# Copier les fichiers de l'application
COPY . /app

# Installer les dépendances
RUN gem install bundler
RUN bundle install

# Exposer uniquement le port WebSocket
EXPOSE 3630

# Démarrer uniquement le serveur WebSocket
CMD ["ruby", "server.rb"]
EOL

  docker build -t hermes_ws -f Dockerfile.ws .
  docker run -d --name hermes_container \
    -p 3630:3630 \
    -e DB_NAME=hermes \
    -e DB_USER=user \
    -e DB_PASS=admin \
    -e DB_HOST=localhost \
    hermes_ws

  echo "Le serveur WebSocket devrait maintenant fonctionner sur le port 3630"
  echo "L'upload de fichiers est temporairement désactivé."
fi
