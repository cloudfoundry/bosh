FROM ubuntu:jammy

ENV DEBIAN_FRONTEND "noninteractive"
ENV RUBY_VERSION "3.1"
ENV RUBY_INSTALL_VERSION "0.8.4"
ENV GEM_HOME "/usr/local/bundle"
ENV POSTGRES_MAJOR_VERSION "10"

RUN apt-get update -y \
    && apt-get -y install --no-install-recommends \
        software-properties-common \
    && apt-get install -y --no-install-recommends \
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
        openssh-client

RUN echo 'gem: --no-document' > /etc/gemrc \
    && curl -sL -O https://github.com/postmodern/ruby-install/archive/refs/tags/v${RUBY_INSTALL_VERSION}.tar.gz \
    && tar -xzf v${RUBY_INSTALL_VERSION}.tar.gz \
    && cd ruby-install-${RUBY_INSTALL_VERSION}/ \
    && make -s install \
    && ruby-install --jobs=2 --cleanup --system ruby ${RUBY_VERSION} -- --disable-install-rdoc \
    && gem update --system \
    && bundle config --global path "${GEM_HOME}" \
    && bundle config --global bin "${GEM_HOME}/bin"

# Database clients
RUN echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    | tee -a /etc/apt/sources.list.d/pgdg.list \
    && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | apt-key add - \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
    mysql-client \
    libmysqlclient-dev \
    postgresql-${POSTGRES_MAJOR_VERSION} \
    postgresql-client-${POSTGRES_MAJOR_VERSION}

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH
