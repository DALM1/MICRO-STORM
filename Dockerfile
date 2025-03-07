FROM golang:1.20

WORKDIR /app

COPY go.mod go.sum ./

COPY . .


RUN go build -o server .

EXPOSE 3630
EXPOSE 4567
EXPOSE 50051

CMD ["./server"]
