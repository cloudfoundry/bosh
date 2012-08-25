#!/bin/bash
#
# script to setup rbenv & ruby
#
set -e

VERSION=1.9.2-p320

if [ "`cat $HOME/.rbenv/version`" = $VERSION ]
then
  exit 0
fi

rbenv install $VERSION
rbenv global $VERSION
