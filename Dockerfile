FROM golang:1.20

WORKDIR /app

# Installer protoc (compilateur Protobuf)
RUN apt-get update && apt-get install -y protobuf-compiler

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN protoc --go_out=. --go-grpc_out=. chatpb/chat.proto

RUN go build -mod=mod -o server .

EXPOSE 3630
EXPOSE 4567
EXPOSE 50051

CMD ["./server"]
