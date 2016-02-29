FROM ubuntu:latest

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update; apt-get -y upgrade; apt-get clean

RUN apt-get install -y git curl tar make; apt-get clean

RUN apt-get install -y python-dateutil python-magic; apt-get clean

RUN apt-get install -y libsqlite3-dev libmysqlclient-dev libpq-dev; apt-get clean

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
RUN /bin/bash -l -c "                                     \
  source /etc/profile.d/chruby.sh ;                       \
  chruby 2.1.2 ;                                          \
  gem install bundler --version 1.11.2 --no-ri --no-rdoc ; \
  gem install bosh_cli --no-ri --no-rdoc                  \
"

RUN cd /tmp && \
    curl -O -L https://github.com/s3tools/s3cmd/archive/v1.6.0.tar.gz && \
    tar xzf v1.6.0.tar.gz && \
    cd s3cmd-1.6.0 && \
    cp -R s3cmd S3 /usr/local/bin && \
    cd /tmp && \
    rm -rf s3cmd-1.6.0/ v1.6.0.tar.gz
