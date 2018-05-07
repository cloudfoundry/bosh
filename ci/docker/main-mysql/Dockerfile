FROM bosh/main-base

ENV DEBIAN_FRONTEND noninteractive

# install extra deb repo {
RUN \
  apt-get update \
  && apt-get install -y \
    software-properties-common \
  && add-apt-repository 'deb http://archive.ubuntu.com/ubuntu trusty universe' \
  && apt-get update
# }

# install the correct version of mysql {
ARG DB_VERSION
RUN \
  apt-get update \
  && apt-get install -y \
    mysql-server$DB_VERSION \
  && apt-get autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
# }
