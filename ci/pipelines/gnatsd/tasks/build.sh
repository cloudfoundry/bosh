#!/usr/bin/env bash

set -e -x -u

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH
export GOPATH=$(pwd)/gopath

base=`pwd`

out="${base}/compiled-${GOOS}"

timestamp=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
git_rev=`git rev-parse --short HEAD`

version="${git_rev}-${timestamp}"

filename="gnatsd-${version}-${GOOS}-${GOARCH}"

cd gopath/src/github.com/nats-io/gnatsd

echo "building ${filename} with version ${version}"
sed -i "s/VERSION = \"\(.*\)\"/VERSION = \"\1+${version}\"/" server/const.go

go build -o ${out}/${filename} github.com/nats-io/gnatsd
