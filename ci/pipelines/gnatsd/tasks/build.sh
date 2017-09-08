#!/usr/bin/env bash

set -e -x -u

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH
export GOPATH=$(pwd)/gopath

base=`pwd`

cd gopath/src/github.com/nats-io/gnatsd

out="${base}/compiled-${GOOS}"

semver=`grep "VERSION =" server/const.go | cut -d\" -f2`
timestamp=`date -u +"%Y-%m-%dT%H_%M_%SZ"`
git_rev=`git rev-parse --short HEAD`

version="${semver}+${git_rev}-${timestamp}"

filename="gnatsd-${version}-${GOOS}-${GOARCH}"

echo "building ${filename} with version ${version}"
sed -i "s/VERSION = \".*\"/VERSION = \"${version}\"/" server/const.go

go build -o ${out}/${filename} github.com/nats-io/gnatsd
