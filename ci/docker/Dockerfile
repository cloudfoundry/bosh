FROM ubuntu:14.10

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update
RUN apt-get -y upgrade; apt-get clean

RUN apt-get install -y build-essential; apt-get clean
RUN apt-get install -y git; apt-get clean
RUN apt-get install -y curl; apt-get clean
RUN apt-get install -y wget; apt-get clean
RUN apt-get install -y tar; apt-get clean

RUN apt-get install -y libssl-dev; apt-get clean
RUN apt-get install -y libreadline-dev; apt-get clean
RUN apt-get install -y dnsutils; apt-get clean
RUN apt-get install -y xvfb; apt-get clean

# Nokogiri dependencies
RUN apt-get install -y libxslt-dev; apt-get clean
RUN apt-get install -y libxml2-dev; apt-get clean

# BOSH dependencies
RUN apt-get install -y mysql-client; apt-get clean
RUN apt-get install -y libmysqlclient-dev; apt-get clean
RUN apt-get install -y postgresql-9.4; apt-get clean
RUN apt-get install -y postgresql-client-9.4; apt-get clean
RUN apt-get install -y libpq-dev; apt-get clean
RUN apt-get install -y sqlite3; apt-get clean
RUN apt-get install -y libsqlite3-dev; apt-get clean
RUN apt-get install -y redis-server; apt-get clean
RUN apt-get install -y mercurial; apt-get clean
RUN apt-get install -y lsof; apt-get clean
RUN apt-get install -y unzip; apt-get clean

ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd /tmp; ./install-ruby.sh; rm install-ruby.sh

ADD install-bundler.sh /tmp/install-bundler.sh
RUN chmod a+x /tmp/install-bundler.sh
RUN cd /tmp; ./install-bundler.sh; rm install-bundler.sh

ADD install-java.sh /tmp/install-java.sh
RUN chmod a+x /tmp/install-java.sh
RUN cd /tmp; ./install-java.sh; rm install-java.sh
ENV JAVA_HOME /usr/lib/jvm/zulu1.8.0_25-8.4.0.1-x86lx64
ENV PATH $JAVA_HOME/bin:$PATH

ENV GOROOT /usr/local/go
ENV PATH $GOROOT/bin:$PATH
ADD install-go.sh /tmp/install-go.sh
RUN chmod a+x /tmp/install-go.sh
RUN cd /tmp; ./install-go.sh; rm install-go.sh

# prepare the image with vcap user, so we can set up postgres
# RUN useradd -mU vcap -s /bin/bash
RUN echo "vcap ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# create postgres data & lock dirs
ENV PGDATA /var/postgres
# RUN mkdir -p /var/postgres && chown vcap:vcap /var/postgres
# RUN mkdir -p /var/run/postgresql && chown vcap:vcap /var/run/postgresql
# RUN mkdir -p /var/log/postgresql && chown vcap:vcap /var/log/postgresql

# postgres must be run as non-root
# postgres user: vcap/<no-password>
# USER vcap
ENV PATH /usr/lib/postgresql/9.4/bin:$PATH
# RUN pg_ctl init && pg_ctl start -l /var/log/postgresql/server.log && sleep 4 && createuser -U vcap --superuser postgres && createdb -U vcap && pg_ctl stop

# mysql must be run as root
# mysql user: root/password
USER root
RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
RUN apt-get install -y mysql-server

RUN git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
RUN git config --global user.name "BOSH CI"
