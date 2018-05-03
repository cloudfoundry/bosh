FROM ubuntu:xenial

# basic deps {
RUN \
  apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    build-essential \
    curl \
    dnsutils \
    git \
    jq \
    libreadline-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    locales \
    tar \
    wget \
  && apt-get autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
# }

# ruby {
ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd /tmp && ./install-ruby.sh && rm install-ruby.sh
# }

# golang {
WORKDIR /usr/local

RUN \
  GO_INFO=$(curl 'https://golang.org/dl/?mode=json' | jq '.[0].files[] | select(.os == "linux" and .arch == "amd64")') && \
  GO_TAR="$(echo "$GO_INFO" | jq -r '.filename')" && \
  GO_SHA="$(echo "$GO_INFO" | jq -r '.sha256')" && \
  curl -fSL https://storage.googleapis.com/golang/$GO_TAR -o $GO_TAR \
  && echo $GO_SHA $GO_TAR | sha256sum -c - \
  && tar -xzf $GO_TAR \
  && rm -f $GO_TAR

ENV \
  PATH=/usr/local/go/bin:$PATH \
  GOPATH=/root/go \
  GOROOT=/usr/local/go
# }
