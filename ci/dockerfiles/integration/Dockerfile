#bosh/integration:main
#
FROM ubuntu:jammy

ENV DEBIAN_FRONTEND "noninteractive"
ENV RUBY_VERSION "3.2"
ENV RUBY_INSTALL_VERSION "0.8.5"
ENV GEM_HOME "/usr/local/bundle"
ENV POSTGRES_MAJOR_VERSION "13"
ENV BOSH_CLI_VERSION 7.2.2-linux-amd64
ENV BOSH_CLI_SHA256SUM "2b01dbdf5192ade3587ad82df127f8ab9a7256d2be23b3f1c37de39f6750fe34"
ENV METALINK_VERSION 0.5.0-linux-amd64

RUN apt-get update -y \
    && apt-get -y install --no-install-recommends \
        software-properties-common \
    && apt-get install -y --no-install-recommends \
        locales \
        unzip \
        qemu-utils \
        awscli \
        build-essential \
        curl \
        coreutils \
        dnsutils \
        git \
        git-lfs \
        gpg-agent \
        jq \
        libcurl4-openssl-dev \
        libpq-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        netcat-openbsd \
        rsyslog \
        sqlite3 \
        sudo \
        tar \
        wget \
        xvfb \
        vim \
        openssh-client \
        clang \
        clang-14 \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386 \
        libclang-common-14-dev \
        libclang-cpp14 \
        libclang1-14 \
        libgc1 \
        libllvm14 \
        libobjc-11-dev \
        libobjc4 \
        llvm-14-linker-tools

RUN cd /tmp && \
    wget -nv "https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSH_CLI_VERSION}" && \
    ( \
        echo "${BOSH_CLI_SHA256SUM} bosh-cli-${BOSH_CLI_VERSION}" | \
        sha256sum -c - \
    ) && \
    mv /tmp/bosh-cli-* /usr/local/bin/bosh && \
    chmod +x /usr/local/bin/bosh

# Install UAA
COPY bosh-deployment /usr/local/bosh-deployment/
RUN \
  cd /usr/local && \
  UAA_RELEASE_URL="$(bosh int /usr/local/bosh-deployment/bosh-deployment/uaa.yml --path /release=uaa/value/url)" \
  curl -o /usr/local/uaa.tgz "$UAA_RELEASE_URL"

RUN cd /tmp && \
    wget -nv "https://github.com/dpb587/metalink/releases/download/v0.5.0/meta4-${METALINK_VERSION}" && \
    ( \
        echo "9f3ff22e1ac3a8b4a667a9505dce2a224e099475ab69a02b23813ad073e27e01 meta4-${METALINK_VERSION}" | \
        sha256sum -c - \
    ) && \
    mv /tmp/meta4-* /usr/local/bin/meta4 && \
    chmod +x /usr/local/bin/meta4


ENV CXX=/usr/bin/clang++ CC=/usr/bin/clang
RUN echo 'gem: --no-document' > /etc/gemrc \
    && curl -sL -O https://github.com/postmodern/ruby-install/archive/refs/tags/v${RUBY_INSTALL_VERSION}.tar.gz \
    && tar -xzf v${RUBY_INSTALL_VERSION}.tar.gz \
    && cd ruby-install-${RUBY_INSTALL_VERSION}/ \
    && make -s install \
    && ruby-install --jobs=2 --cleanup --system ruby ${RUBY_VERSION} -- --disable-install-rdoc -- CC=clang

RUN gem update --system \
    && bundle config --global path "${GEM_HOME}" \
    && bundle config --global bin "${GEM_HOME}/bin"

COPY --from=golang:latest /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

# Java to start UAA
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

ADD install-java.sh /tmp/install-java.sh
RUN chmod a+x /tmp/install-java.sh
RUN cd /tmp && ./install-java.sh && rm install-java.sh
ENV JAVA_HOME /usr/lib/jvm/
ENV PATH $JAVA_HOME/bin:$PATH

# Database clients
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/psql_org.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    | tee -a /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/psql_org.gpg \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
    mysql-client \
    libmysqlclient-dev \
    postgresql-client-${POSTGRES_MAJOR_VERSION}
