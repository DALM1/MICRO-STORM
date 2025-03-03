#!/bin/bash
cd /root/MICRO-STORM
docker rm -f hermes_container 2>/dev/null
mv gemfile Gemfile 2>/dev/null
apt-get update
apt-get install -y build-essential libprotobuf-dev protobuf-compiler
bundle install --jobs=4 --retry=3
docker build -t hermes .
docker run -d --name hermes_container \
  -p 3630:3630 \
  -p 4567:4567 \
  -p 50051:50051 \
  -e DB_NAME=hermes \
  -e DB_USER=user \
  -e DB_PASS=admin \
  -e DB_HOST=localhost \
  hermes
