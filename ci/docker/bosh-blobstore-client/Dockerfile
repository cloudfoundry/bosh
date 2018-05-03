FROM ubuntu:xenial

RUN \
  apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install \
    curl \
    git \
    libmysqlclient-dev \
    libpq-dev \
    libsqlite3-dev \
    locales \
    make \
    python-dateutil \
    python-magic \
    tar \
  && apt-get clean

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# chruby
RUN mkdir /tmp/chruby && \
    cd /tmp && \
    curl https://codeload.github.com/postmodern/chruby/tar.gz/v0.3.9 | tar -xz && \
    cd /tmp/chruby-0.3.9 && \
    ./scripts/setup.sh && \
    rm -rf /tmp/chruby

# ruby-install
RUN mkdir /tmp/ruby-install && \
    cd /tmp && \
    curl https://codeload.github.com/postmodern/ruby-install/tar.gz/v0.5.0 | tar -xz && \
    cd /tmp/ruby-install-0.5.0 && \
    make install && \
    rm -rf /tmp/ruby-install

# ruby
RUN ruby-install ruby 2.1.2
RUN ruby-install ruby 2.4.2

# Bundler and BOSH CLI for ruby 2.4.2
RUN /bin/bash -l -c "                                     \
  source /etc/profile.d/chruby.sh ;                       \
  chruby 2.4.2 ;                                          \
  gem install bundler --version 1.15.3 --no-ri --no-rdoc ; \
  gem install bosh_cli --no-ri --no-rdoc                  \
"

# Bundler and BOSH CLI for ruby 2.1.2
RUN /bin/bash -l -c "                                     \
  source /etc/profile.d/chruby.sh ;                       \
  chruby 2.1.2 ;                                          \
  gem install bundler --version 1.15.3 --no-ri --no-rdoc ; \
  gem install bosh_cli --no-ri --no-rdoc                  \
"

# Install bosh-cli
RUN curl -o /usr/local/bin/bosh2 https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.45-linux-amd64 && echo "bf04be72daa7da0c9bbeda16fda7fc7b2b8af51e  /usr/local/bin/bosh2" | sha1sum -c - && chmod +x /usr/local/bin/bosh2

RUN cd /tmp && \
    curl -O -L https://github.com/s3tools/s3cmd/archive/v1.6.0.tar.gz && \
    tar xzf v1.6.0.tar.gz && \
    cd s3cmd-1.6.0 && \
    cp -R s3cmd S3 /usr/local/bin && \
    cd /tmp && \
    rm -rf s3cmd-1.6.0/ v1.6.0.tar.gz

ENV GCLOUD_VERSION=157.0.0
ENV GCLOUD_SHA1SUM=383522491db5feb9f03053f29aaf6a1cf778e070

RUN mkdir /tmp/gcloud-install && \
    cd /tmp/gcloud-install && \
    curl -L -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz && \
    echo "${GCLOUD_SHA1SUM}  google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz" > gcloud_${GCLOUD_VERSION}_SHA1SUM && \
    sha1sum -cw --status gcloud_${GCLOUD_VERSION}_SHA1SUM && \
    tar xvf google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz && \
    mv google-cloud-sdk / && cd /google-cloud-sdk  && ./install.sh && \
    cd /tmp && \
    rm -rf gcloud-install

ENV PATH=$PATH:/google-cloud-sdk/bin
