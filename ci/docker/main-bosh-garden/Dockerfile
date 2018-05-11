FROM ubuntu

# install basic deps {
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
    jq \
    lsb-release \
    openssh-client \
    pkg-config \
    quota \
    ruby \
    software-properties-common \
    sshpass \
    sudo \
    uidmap \
    ulogd2 \
    xfsprogs \
    zip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
# }

# install libseccomp (needed for garden-runc) {
RUN \
  curl -LO https://github.com/seccomp/libseccomp/releases/download/v2.3.1/libseccomp-2.3.1.tar.gz && \
  tar zxf libseccomp-2.3.1.tar.gz && \
  cd libseccomp-2.3.1/  && \
  ./configure && \
  make && \
  make install
# }

# golang {
WORKDIR /usr/local

RUN \
  GO_INFO=$(curl 'https://golang.org/dl/?mode=json' | jq '.[0].files[] | select(.os == "linux" and .arch == "amd64")') && \
  GO_TAR="$(echo "$GO_INFO" | jq -r '.filename')" && \
  GO_SHA="$(echo "$GO_INFO" | jq -r '.sha256')" && \
  curl -fSL https://storage.googleapis.com/golang/$GO_TAR -o $GO_TAR \
  && echo $GO_SHA $GO_TAR | sha256sum -c - \
  && tar -xzf $GO_TAR

ENV \
  PATH=/usr/local/go/bin:$PATH \
  GOPATH=/root/go \
  GOROOT=/usr/local/go
# }

# install garden {
ADD ./install-garden.sh /tmp/install-garden.sh
RUN /tmp/install-garden.sh
RUN rm /tmp/install-garden.sh

COPY start-garden.sh /usr/local/bin/start-garden
RUN chmod +x /usr/local/bin/start-garden
# }

# install bosh {
COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh
# }
