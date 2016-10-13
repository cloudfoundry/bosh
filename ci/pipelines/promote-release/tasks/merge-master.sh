#!/bin/sh

set -e -x

export PATH=$GOPATH/bin:$PATH

DEVELOP=$PWD/bosh-src-develop

git clone ./bosh-src-master ./bosh-src-merged

cd bosh-src-merged

git remote add local $DEVELOP

git fetch local
git checkout local/develop

git config --global user.email "ci@localhost"
git config --global user.name "CI Bot"

git merge --no-edit master
