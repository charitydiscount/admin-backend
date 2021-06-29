# syntax=docker/dockerfile:1.2

FROM --platform=${BUILDPLATFORM} golang:1.16.5-alpine3.14 AS base
WORKDIR /src
ENV CGO_ENABLED=0

COPY go.* .
RUN go mod download
COPY . .

FROM base AS build
ARG TARGETOS
ARG TARGETARCH
RUN --mount=type=cache,target=/root/.cache/go-build \
  GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
  go build -o /out/admin .

FROM base AS unit-test
RUN --mount=type=cache,target=/root/.cache/go-build \
  go test -v .

FROM golangci/golangci-lint:v1.41-alpine AS lint-base

FROM base AS lint
RUN --mount=target=. \
  --mount=from=lint-base,src=/usr/bin/golangci-lint,target=/usr/bin/golangci-lint \
  --mount=type=cache,target=/root/.cache/go-build \
  --mount=type=cache,target=/root/.cache/golangci-lint \
  golangci-lint run --timeout 10m0s ./...

FROM scratch AS bin-unix
COPY --from=build /out/admin /

FROM bin-unix AS bin-linux
FROM bin-unix AS bin-darwin

FROM scratch AS bin-windows
COPY --from=build /out/admin /admin.exe

FROM bin-${TARGETOS} AS bin
