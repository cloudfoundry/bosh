FROM ubuntu:xenial

# basic deps {
RUN \
  apt-get update \
  && apt-get install -y --no-install-recommends \
    apt-transport-https \
    curl \
    dnsutils \
    git \
    iproute2 \
    jq \
    openssh-client \
    ruby \
    software-properties-common \
  && (curl -fsSL https://apt.dockerproject.org/gpg | apt-key add -) \
  && add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main" \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    docker-engine \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
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

# install bosh {
COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh
# }
