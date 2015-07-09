#!/usr/bin/env bash

cd bosh-src

git diff --exit-code develop origin/develop

if ["$?" -eq "0"]
then
  echo "develop is up to date with origin. Continuing with this build."
  exit 0
else
  echo "develop is behind origin. Aborting so the next queued build can run."
  exit 1
fi
