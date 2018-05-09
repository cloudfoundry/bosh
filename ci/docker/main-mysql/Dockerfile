FROM bosh/main-base

ENV DEBIAN_FRONTEND noninteractive
ARG DB_VERSION

# install the correct version of mysql {
RUN \
  echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections \
  && echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections \
  && apt-get update \
  && apt-get install -y \
    mysql-server-$DB_VERSION \
  && apt-get autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
# }
