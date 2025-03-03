#!/bin/bash
cd /root/MICRO-STORM
mv gemfile Gemfile 2>/dev/null
docker rm -f hermes_container 2>/dev/null
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
