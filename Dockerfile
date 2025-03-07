FROM golang:1.20

WORKDIR /app

ENV GO111MODULE=on

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -mod=mod -o server .

EXPOSE 3630
EXPOSE 4567
EXPOSE 50051

CMD ["./server"]
