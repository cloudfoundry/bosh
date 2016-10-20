#!/bin/sh

set -e -x

export PATH=$GOPATH/bin:$PATH

DEVELOP=$PWD/bosh-src-develop
CANDIDATE=$PWD/bosh-src-candidate

git config --global user.email "ci@localhost"
git config --global user.name "CI Bot"

merge_branch() {
  branch_name=$1

  repo_name="bosh-src-${branch_name}-merged"
  git clone ./bosh-src-master ./$repo_name
  cd $repo_name

  git remote add local $2

  git fetch local
  git checkout local/$branch_name

  git merge --no-edit master

  cd -
}

merge_branch develop $DEVELOP
merge_branch candidate $CANDIDATE
