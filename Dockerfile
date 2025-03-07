FROM golang:1.20

ENV GO111MODULE=off

WORKDIR /go/src/storm

COPY . .
RUN go build -o server .

EXPOSE 3630
EXPOSE 4567
EXPOSE 50051

CMD ["./server"]
