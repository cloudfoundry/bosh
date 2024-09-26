# bosh/integration:main
FROM ubuntu:jammy

ARG BOSH_CLI_URL
ARG META4_CLI_URL
ARG GOLANGCI_LINT_INSTALL_URL
ARG YQ_CLI_URL

ARG RUBY_INSTALL_URL
ARG GEM_HOME
ARG RUBY_VERSION

ARG UAA_RELEASE_URL
ARG JAVA_INSTALL_PREFIX


ARG POSTGRES_MAJOR_VERSION

ENV DEBIAN_FRONTEND="noninteractive"
ENV LANG="en_US.UTF-8"
ENV LC_ALL="${LANG}"
ENV TZ="Etc/UTC"

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        software-properties-common \
        curl \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/psql_org.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
      | tee -a /etc/apt/sources.list.d/pgdg.list \
    && curl --show-error -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | gpg --dearmor -o /etc/apt/trusted.gpg.d/psql_org.gpg \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        locales \
        unzip \
        qemu-utils \
        awscli \
        build-essential \
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
        llvm-14-linker-tools \
        mysql-client \
        libmysqlclient-dev \
        postgresql-client-${POSTGRES_MAJOR_VERSION} \
    && locale-gen ${LANG}


RUN bosh_cli_path="/usr/bin/bosh" \
    && curl --show-error -sL "${BOSH_CLI_URL}" \
      > "${bosh_cli_path}" \
    && chmod +x "${bosh_cli_path}"

RUN meta4_cli_path="/usr/local/bin/meta4" \
    && curl --show-error -sL "${META4_CLI_URL}" \
      > "${meta4_cli_path}" \
    && chmod +x "${meta4_cli_path}"

RUN cd /tmp \
    && golangci_lint_path="/usr/local/bin/golangci-lint" \
    && curl --show-error -sL "${GOLANGCI_LINT_INSTALL_URL}" \
      | tar -xzf - \
    && mv golangci-lint-*-linux-amd64/golangci-lint "${golangci_lint_path}" \
    && rm -rf golangci-lint-*-linux-amd64 \
    && chmod +x "${golangci_lint_path}"

RUN yq_cli_path="/usr/local/bin/yq" \
    && curl --show-error -sL "${YQ_CLI_URL}" \
      > "${yq_cli_path}" \
    && chmod +x "${yq_cli_path}"


ENV CC="/usr/bin/clang" CXX="/usr/bin/clang++"
RUN cd /tmp  \
    && curl --show-error -sL "${RUBY_INSTALL_URL}" \
      | tar -xzf - \
    && cd ruby-install-* \
    && make -s install \
    && cd - \
    && rm -rf ruby-install-* \
    && echo 'gem: --no-document' > /etc/gemrc \
    && NUM_CPUS=$(grep -c ^processor /proc/cpuinfo) \
    && ruby-install --jobs=${NUM_CPUS} --cleanup --system ruby ${RUBY_VERSION} \
      -- --disable-install-doc --disable-install-rdoc \
      -- CC=clang \
    && gem update --system \
    && bundle config --global path "${GEM_HOME}" \
    && bundle config --global bin "${GEM_HOME}/bin"
ENV PATH=${GEM_HOME}/bin:${PATH}


# Add Golang
COPY --from=golang:latest /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go
ENV PATH=/usr/local/go/bin:${PATH}


# Install UAA && Java
RUN uaa_tgz="/usr/local/uaa.tgz" \
    && curl --show-error -sL "${UAA_RELEASE_URL}" \
      > "${uaa_tgz}" \
    && cd /tmp \
    && uaa_release_dir="uaa-release" \
    && mkdir -p "${uaa_release_dir}" \
    && tar xf "${uaa_tgz}" -C "${uaa_release_dir}" \
    && uaa_packages_dir="uaa-packages" \
    && mkdir -p "${uaa_packages_dir}" \
    && tar xf "${uaa_release_dir}/compiled_packages/uaa.tgz" -C "${uaa_packages_dir}" \
    && mv "${uaa_packages_dir}/jdk" "${JAVA_INSTALL_PREFIX}" \
    && rm -rf /tmp/uaa-*
ENV JAVA_HOME="${JAVA_INSTALL_PREFIX}"
ENV PATH=${JAVA_HOME}/bin:${PATH}
