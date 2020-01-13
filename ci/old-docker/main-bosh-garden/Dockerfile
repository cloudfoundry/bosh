FROM ubuntu:xenial

RUN \
  apt-get update && \
  apt-get -y install \
    apt-transport-https \
    autoconf \
    btrfs-tools \
    ca-certificates \
    curl \
    dnsutils \
    git \
    iproute2 \
    iptables \
    lsb-release \
    openssh-client \
    pkg-config \
    quota \
    ruby \
    software-properties-common \
    sshpass \
    sudo \
    uidmap \
    ulogd \
    xfsprogs \
    zip \
  && \
  apt-get clean

# install libseccomp (needed for garden-runc)
RUN \
  curl -LO https://github.com/seccomp/libseccomp/releases/download/v2.3.1/libseccomp-2.3.1.tar.gz && \
  tar zxf libseccomp-2.3.1.tar.gz && \
  cd libseccomp-2.3.1/  && \
  ./configure && \
  make && \
  make install

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

ADD ./install-garden.sh /tmp/install-garden.sh
RUN /tmp/install-garden.sh
RUN rm /tmp/install-garden.sh

COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh

COPY start-garden.sh /usr/local/bin/start-garden
RUN chmod +x /usr/local/bin/start-garden
