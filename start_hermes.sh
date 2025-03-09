#!/bin/bash
cd /root/MICRO-STORM
docker rm -f hermes_container 2>/dev/null
mv gemfile Gemfile 2>/dev/null
bundle
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
