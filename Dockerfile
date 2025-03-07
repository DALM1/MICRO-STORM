FROM golang:1.20

WORKDIR /app

# Copier les fichiers go.mod et go.sum et télécharger les dépendances
COPY go.mod go.sum ./
RUN go mod download

# Copier l'intégralité du projet
COPY . .

# Générer les fichiers protobuf (si ce n'est pas déjà fait localement)
RUN protoc --go_out=. --go-grpc_out=. chatpb/chat.proto

# Compiler le projet
RUN go build -o server .

EXPOSE 3630
EXPOSE 4567
EXPOSE 50051

CMD ["./server"]
