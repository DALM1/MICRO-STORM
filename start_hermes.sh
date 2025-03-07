#!/bin/bash

cd /root/MICRO-STORM

docker rm -f hermes_container 2>/dev/null

docker run protoc --go_out=. --go-grpc_out=. chatpb/chat.proto 2>/dev/null

docker build -t hermes .

docker run -d --name hermes_container \
  -p 3630:3630 \
  -p 4567:4567 \
  -p 50051:50051 \
  -e MSG_DB_NAME=messages_db \
  -e MSG_DB_USER=pguser \
  -e MSG_DB_PASS=pgpassword \
  -e MSG_DB_HOST=localhost \
  hermes
