# Build the radicle-cloud operator
FROM golang:1.16 as builder

ARG TARGETARCH
ARG GIT_HEAD_COMMIT
ARG GIT_TAG_COMMIT
ARG GIT_LAST_TAG
ARG GIT_MODIFIED
ARG GIT_REPO
ARG BUILD_DATE

# Install deps
WORKDIR /build
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download

# Copy source files
COPY main.go main.go
COPY db/ db/
COPY eth/ eth/
COPY cloud/ cloud/
COPY utils/ utils/

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH GO111MODULE=on go build \
        -gcflags "-N -l" \
        -ldflags "-X main.GitRepo=$GIT_REPO -X main.GitTag=$GIT_LAST_TAG -X main.GitCommit=$GIT_HEAD_COMMIT -X main.GitDirty=$GIT_MODIFIED -X main.BuildTime=$BUILD_DATE" \
        -o radicle-cloud

FROM ubuntu:18.04

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Install Ansible
RUN apt-get update && apt-get install -y \
  openssh-server \
  python3-pip && \
  pip3 install --upgrade pip && \
  pip3 install ansible

WORKDIR /
COPY --from=builder /build/radicle-cloud .
COPY ansible/ ansible/
COPY Caddyfile Caddyfile

RUN useradd --user-group --create-home --no-log-init ops
USER ops

CMD ["/radicle-cloud"]
