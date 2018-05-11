FROM ubuntu:trusty

#basic deps {
RUN \
  apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y \
    build-essential \
    curl \
    dnsutils \
    git \
    jq \
    libmariadbclient-dev \
    libpq-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libxslt-dev \
    lsof \
    mercurial \
    realpath \
    realpath \
    redis-server \
    sqlite3 \
    tar \
    unzip \
    wget \
    xvfb \
  && apt-get autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
# }

# install ruby {
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

# install UAA dependencies {
RUN \
  mkdir -p /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3 \
  && cd /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3 \
  && curl -L https://s3.amazonaws.com/bosh-dependencies/apache-tomcat-8.0.21.tar.gz | tar xfz - \
  && curl --output /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3/apache-tomcat-8.0.21/webapps/uaa.war \
    -L https://s3.amazonaws.com/bosh-dependencies/cloudfoundry-identity-uaa-2.0.3.war \
  && curl -L --output /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
  && chmod +x /usr/local/bin/jq

# install java {
RUN \
  export PACKAGE_NAME="zulu8.23.0.3-jdk8.0.144-linux_x64.tar.gz" \
  && export PACKAGE_MD5="6ecd67688407b9f7e45c2736f003398b" \
  && export PACKAGE_TMP="/tmp/${PACKAGE_NAME}" \
  && export PACKAGE_URL="http://cdn.azul.com/zulu/bin/${PACKAGE_NAME}" \
  && export INSTALL_PREFIX="/usr/lib/jvm" \
  && wget -O $PACKAGE_TMP --continue $PACKAGE_URL \
  && (echo "${PACKAGE_MD5}  ${PACKAGE_TMP}" | md5sum -c -) \
  && mkdir -p "${INSTALL_PREFIX}" \
  && tar xf "${PACKAGE_TMP}" -C "${INSTALL_PREFIX}" \
  && rm "${PACKAGE_TMP}"
# }

ENV JAVA_HOME /usr/lib/jvm/zulu8.23.0.3-jdk8.0.144-linux_x64
ENV PATH $JAVA_HOME/bin:$PATH

RUN \
  git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io" \
  && git config --global user.name "BOSH CI"

RUN date > /var/docker-image-timestamp
# }

# install specific version of mysql {
RUN \
  echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections \
  && echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections \
  && apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5 \
  && echo "deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7" > /etc/apt/sources.list.d/mysql.list \
  && apt-get update \
  && apt-get install -y \
      mysql-server \
  && apt-get autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*
# }
