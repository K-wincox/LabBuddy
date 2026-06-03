FROM golang:1.22-bookworm AS build

WORKDIR /src
ENV GOPROXY=https://goproxy.cn,direct
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/labbuddy-api ./cmd/api

FROM debian:bookworm-slim

WORKDIR /app
COPY --from=build /out/labbuddy-api /app/labbuddy-api
COPY migrations /app/migrations
EXPOSE 8088
RUN useradd --system --uid 10001 --home /app labbuddy
USER labbuddy
ENTRYPOINT ["/app/labbuddy-api"]
