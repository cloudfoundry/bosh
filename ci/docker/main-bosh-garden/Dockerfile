FROM bosh/main-ruby-go

RUN \
  apt-get update && \
  apt-get -y install \
    autoconf \
    btrfs-tools \
    iptables \
    lsb-release \
    pkg-config \
    quota \
    sudo \
    uidmap \
    ulogd \
    zip \
  && \
  apt-get clean

# install libseccomp (needed for garden-runc)
RUN \
  wget https://github.com/seccomp/libseccomp/releases/download/v2.3.1/libseccomp-2.3.1.tar.gz && \
  tar zxf libseccomp-2.3.1.tar.gz && \
  cd libseccomp-2.3.1/  && \
  ./configure && \
  make && \
  make install

ADD ./install-garden.sh /tmp/install-garden.sh
RUN /tmp/install-garden.sh
RUN rm /tmp/install-garden.sh

COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh
