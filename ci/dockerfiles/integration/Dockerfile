# ghcr.io/cloudfoundry/bosh/integration:main
ARG BASE_IMAGE
# Set by BuildKit (amd64 or arm64). It selects the golang-release image and the
# per-architecture install steps below.
ARG TARGETARCH

FROM ghcr.io/cloudfoundry/bosh/golang-release:latest AS golang-amd64
FROM ghcr.io/cloudfoundry/bosh/golang-release:latest-arm64 AS golang-arm64
FROM golang-${TARGETARCH} AS golang

FROM $BASE_IMAGE
ARG TARGETARCH

ARG BOSH_CLI_URL
ARG CREDHUB_CLI_URL
ARG CREDHUB_CLI_VERSION
ARG META4_CLI_URL
ARG META4_VERSION
ARG GOLANGCI_LINT_INSTALL_URL
ARG YQ_CLI_URL

ARG RUBY_INSTALL_URL
ARG GEM_HOME
ARG RUBY_VERSION

ARG UAA_RELEASE_URL
ARG JDK_URL
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
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor \
      | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
    && echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
      | tee /etc/apt/sources.list.d/azure-cli.list \
    && curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        locales \
        unzip \
        qemu-utils \
        azure-cli \
        build-essential \
        ca-certificates \
        coreutils \
        default-libmysqlclient-dev \
        dnsutils \
        file \
        git \
        git-lfs \
        google-cloud-cli \
        gpg-agent \
        jq \
        libcurl4-openssl-dev \
        libpcap-dev \
        libpq-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        lsof \
        netcat-openbsd \
        psmisc \
        rsyslog \
        sshpass \
        strace \
        sqlite3 \
        sudo \
        tar \
        wget \
        xvfb \
        zlib1g-dev \
        vim \
        openssh-client \
        openssh-server \
        mysql-client \
        libmysqlclient-dev \
        postgresql-client-${POSTGRES_MAJOR_VERSION} \
    && locale-gen ${LANG}


RUN bosh_cli_path="/usr/bin/bosh" \
    && curl --show-error -sL "${BOSH_CLI_URL}" \
      > "${bosh_cli_path}" \
    && chmod +x "${bosh_cli_path}"

# credhub-cli and dpb587/metalink publish linux-amd64 binaries only; on arm64
# both are built from source once Go is installed (see below).
RUN case "${TARGETARCH}" in \
      amd64) curl --show-error -sL "${CREDHUB_CLI_URL}" \
               | tar -xz -C /usr/local/bin ./credhub \
             && chmod +x /usr/local/bin/credhub ;; \
      arm64) ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac

RUN case "${TARGETARCH}" in \
      amd64) meta4_cli_path="/usr/local/bin/meta4" \
             && curl --show-error -sL "${META4_CLI_URL}" \
               > "${meta4_cli_path}" \
             && chmod +x "${meta4_cli_path}" ;; \
      arm64) ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac

RUN cd /tmp \
    && golangci_lint_path="/usr/local/bin/golangci-lint" \
    && curl --show-error -sL "${GOLANGCI_LINT_INSTALL_URL}" \
      | tar -xzf - \
    && mv golangci-lint-*-linux-${TARGETARCH}/golangci-lint "${golangci_lint_path}" \
    && rm -rf golangci-lint-*-linux-${TARGETARCH} \
    && chmod +x "${golangci_lint_path}"

RUN yq_cli_path="/usr/local/bin/yq" \
    && curl --show-error -sL "${YQ_CLI_URL}" \
      > "${yq_cli_path}" \
    && chmod +x "${yq_cli_path}"


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
    && gem update --system \
    && bundle config set --global path "${GEM_HOME}" \
    && bundle config set --global bin "${GEM_HOME}/bin"
ENV PATH=${GEM_HOME}/bin:${PATH}


# Add Golang
COPY --from=golang /var/vcap/packages/golang-1-linux /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

RUN case "${TARGETARCH}" in \
      amd64) ;; \
      arm64) git clone --depth 1 --branch "${CREDHUB_CLI_VERSION}" \
               https://github.com/cloudfoundry/credhub-cli.git /tmp/credhub-cli \
             && ( cd /tmp/credhub-cli && go build \
                    -ldflags "-X code.cloudfoundry.org/credhub-cli/version.Version=${CREDHUB_CLI_VERSION}" \
                    -o /usr/local/bin/credhub . ) \
             && git clone --depth 1 --branch "${META4_VERSION}" \
               https://github.com/dpb587/metalink.git /tmp/metalink \
             && ( cd /tmp/metalink && go build -o /usr/local/bin/meta4 ./cli ) \
             && rm -rf /tmp/credhub-cli /tmp/metalink "$(go env GOCACHE)" "$(go env GOMODCACHE)" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac


# Install UAA && Java
# The JDK in UAA's compiled release is x86_64, so arm64 installs the same
# vendor's (BellSoft Liberica) aarch64 JDK instead.
RUN case "${TARGETARCH}" in \
      amd64) uaa_tgz="/usr/local/uaa.tgz" \
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
             && rm -rf /tmp/uaa-* ;; \
      arm64) mkdir -p "${JAVA_INSTALL_PREFIX}" \
             && curl --fail --show-error -sL "${JDK_URL}" \
               | tar -xz -C "${JAVA_INSTALL_PREFIX}" --strip-components=1 ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac
ENV JAVA_HOME="${JAVA_INSTALL_PREFIX}"
ENV PATH=${JAVA_HOME}/bin:${PATH}

# AWS CLI package exists for Jammy, but not for Noble
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf ./aws \
    && rm awscliv2.zip
