FROM golang:1.20.6 as builder
ENV GO111MODULE=on \
    CGO_ENABLED=0
WORKDIR /go/src/github.com/khulnasoft/netscale/
RUN apt-get update
COPY . .
# compile netscale
RUN make netscale
RUN cp /go/src/github.com/khulnasoft/netscale/netscale /usr/local/bin/
