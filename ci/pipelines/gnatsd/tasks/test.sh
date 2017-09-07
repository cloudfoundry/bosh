#!/usr/bin/env bash

set -e -x

source ~/.bashrc

export GOPATH=$(pwd)/gopath
export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$GOPATH/bin:$PATH

cd $GOPATH/src/github.com/nats-io/gnatsd

service rsyslog start

go get -t ./...
go test ./...
