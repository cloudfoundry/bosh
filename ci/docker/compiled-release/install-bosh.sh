#!/usr/bin/env bash

set -e

# Install BOSH dependencies
echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/pgdg.list && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update
apt-get install -y \
	mysql-client \
	libmariadbclient-dev \
	postgresql-client-9.4 \
	libpq-dev \
	sqlite3 \
	libsqlite3-dev \
	mercurial \
	lsof \
	unzip \
	realpath
apt-get clean

# Install bosh-init
wget https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-0.0.81-linux-amd64 -O /bin/bosh-init
chmod +x /bin/bosh-init

# Install BOSH CLI
gem install bosh_cli --no-ri --no-rdoc
