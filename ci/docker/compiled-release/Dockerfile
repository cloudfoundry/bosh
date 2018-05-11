FROM bosh/main-ruby-go

# install extra dependencies {
RUN \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
  && (wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -) \
  && apt-get update \
  && apt-get install -y \
    mysql-client \
    libmariadbclient-dev \
    postgresql-client-9.4 \
    libpq-dev \
    sqlite3 \
    libsqlite3-dev \
    mercurial \
    lsof \
    unzip \
    realpath \
  && apt-get autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
# }

# Install bosh-cli {
RUN \
  wget https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-0.0.147-linux-amd64 -O /bin/bosh-cli \
  && (echo "533342d7663c3e5dc731769e157608c74dd9eccb  /bin/bosh-cli" | sha1sum -c -) \
  && chmod +x /bin/bosh-cli \
  && /bin/bash -c "source /etc/profile.d/chruby.sh; chruby ruby; gem install bosh_cli --no-ri --no-rdoc"
# }
