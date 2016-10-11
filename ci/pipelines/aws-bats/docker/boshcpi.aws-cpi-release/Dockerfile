FROM ubuntu:15.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update; apt-get -y upgrade; apt-get clean

RUN apt-get install -y git curl wget tar make unzip; apt-get clean

RUN apt-get install -y sqlite3 libsqlite3-dev; apt-get clean

RUN apt-get install -y mysql-client libmysqlclient-dev; apt-get clean

RUN apt-get install -y libpq-dev; apt-get clean

RUN apt-get install -y python python-pip groff jq; apt-get clean; pip install awscli;

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

# Bundler and BOSH CLI
RUN /bin/bash -l -c "                            \
  source /etc/profile.d/chruby.sh ;              \
  chruby 2.1.2 ;                                 \
  gem install bundler bosh_cli --no-ri --no-rdoc \
"

# Pre-Bundle the bosh-cpi-release
COPY bosh_aws_cpi /tmp/bosh_aws_cpi
RUN /bin/bash -l -c "               \
  source /etc/profile.d/chruby.sh ; \
  chruby 2.1.2 ;                    \
  pushd /tmp/bosh_aws_cpi ;     \
  bundle ;                          \
  popd ;                            \
  rm -rf /tmp/bosh_aws_cpi ;    \
"

RUN cd /tmp && \
    curl -o certify-artifacts -L https://s3.amazonaws.com/bosh-certification-generator-releases/certify-artifacts-linux-amd64 && \
    chmod +x certify-artifacts && \
    mv certify-artifacts /bin/certify-artifacts
