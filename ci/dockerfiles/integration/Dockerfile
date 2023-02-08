#bosh/integration:main
#
FROM ubuntu:latest

ENV DEBIAN_FRONTEND "noninteractive"
ENV RUBY_VERSION "3.2"
ENV RUBY_SHA512="733ecc6709470ee16916deeece9af1c76220ae95d17b2681116aff7f381d99bc3124b1b11b1c2336b2b29e468e91b90f158d5ae5fca810c6cf32a0b6234ae08e"
ENV RUBY_INSTALL_VERSION "0.8.5"
ENV GEM_HOME "/usr/local/bundle"
ENV POSTGRES_MAJOR_VERSION "13"
ENV BOSH_CLI_VERSION 7.1.2-linux-amd64
ENV BOSH_CLI_SHA256SUM "bac6d4ee6b735b2ad061727b4abb7ec12d687b7274a10174dc18b84903380f40"
ENV METALINK_VERSION 0.3.0-linux-amd64

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

RUN cd /tmp && \
    wget -nv "https://github.com/dpb587/metalink/releases/download/v0.3.0/meta4-${METALINK_VERSION}" && \
    ( \
        echo "e276ccff74cbe9a85eda17e5955df0b0b06ee68fcdb67d860f691d41b34f65cf meta4-${METALINK_VERSION}" | \
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
    && ruby-install --sha512 $RUBY_SHA512 --jobs=2 --cleanup --system ruby ${RUBY_VERSION} -- --disable-install-rdoc -- CC=clang

RUN gem update --system \
    && bundle config --global path "${GEM_HOME}" \
    && bundle config --global bin "${GEM_HOME}/bin"

COPY --from=golang:1.19 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

# Java to start UAA
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

ADD install-java.sh /tmp/install-java.sh
RUN chmod a+x /tmp/install-java.sh
RUN cd /tmp && ./install-java.sh && rm install-java.sh
ENV JAVA_HOME /usr/lib/jvm/zulu8.23.0.3-jdk8.0.144-linux_x64
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


