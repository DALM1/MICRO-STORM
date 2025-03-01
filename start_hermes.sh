#!/bin/bash
cd /chemin/vers/ton/projet
docker build -t hermes .
docker run -d --name hermes_container \
  -p 3630:3630 \
  -p 4567:4567 \
  -e DB_NAME=ma_base \
  -e DB_USER=mon_user \
  -e DB_PASS=mon_pass \
  -e DB_HOST=localhost \
  hermes
