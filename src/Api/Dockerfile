FROM golang:1.25 AS builder
WORKDIR /app
COPY ./src/Api/go.mod ./Api/
RUN cd ./Api && go mod tidy
COPY ./src/Api/ ./Api/
RUN cd ./Api && go build -o ./bin/api .

FROM debian:latest
WORKDIR /root/
COPY --from=builder /app/Api/bin/api .
RUN chmod +x ./api
CMD ["./api"]
