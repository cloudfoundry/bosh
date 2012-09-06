#!/bin/bash
#
# script to make sure we have all pieces to run ami.rb
#
set -e

if [ -f /etc/gemrc ]
then
  exit 0
fi

sudo apt-get update
sudo apt-get install -y git-core build-essential libsqlite3-dev curl libmysqlclient-dev libxml2-dev libxslt-dev libpq-dev

sudo cp stemcell-copy /usr/local/bin/stemcell-copy
sudo chmod 755 /usr/local/bin/stemcell-copy

git clone https://github.com/sstephenson/rbenv.git .rbenv
mkdir $HOME/.rbenv/plugins
git clone https://github.com/sstephenson/ruby-build.git .rbenv/plugins/ruby-build

echo 'export PATH="$HOME/.rbenv/bin:$PATH"' > ~/.bash_rbenv
echo 'eval "$(rbenv init -)"' >> ~/.bash_rbenv

# add it to both as we run in non-interactive over ssh
cp ~/.bashrc ~/.bashrc.orig
echo '. ~/.bash_rbenv' > ~/.bashrc
cat ~/.bashrc.orig >> ~/.bashrc
echo '. ~/.bash_rbenv' >> ~/.bash_profile

sudo sh -c 'echo "gem: --no-ri --no-rdoc" > /etc/gemrc'
