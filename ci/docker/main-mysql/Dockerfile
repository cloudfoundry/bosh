#FROM bosh/main-base
FROM ubuntu:xenial

ARG DB_VERSION

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get clean && apt-get update && apt-get install -y locales
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# from main-ruby-go
RUN apt-get install -y \
	build-essential \
	git \
	curl \
	wget \
	tar \
	libssl-dev \
	libreadline-dev \
	dnsutils \
	xvfb \
	jq \
	realpath \
	libpq-dev

RUN apt-get install -y libxslt-dev libxml2-dev && apt-get clean

ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd /tmp && ./install-ruby.sh && rm install-ruby.sh

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH
ENV PATH /opt/rubies/ruby-2.6.3/bin:/opt/rubies/ruby-2.4.5/bin:$PATH

RUN locale-gen en_US.UTF-8
#----- end main ruby go

RUN apt-get install -y \
	libmariadb-client-lgpl-dev \
	redis-server \
	libpq-dev \
	sqlite3 \
	libsqlite3-dev \
	mercurial \
	lsof \
	unzip \
	realpath \
	&& apt-get clean

# UAA dependencies
RUN mkdir -p /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3
RUN curl -L https://s3.amazonaws.com/bosh-dependencies/apache-tomcat-8.0.21.tar.gz | (cd /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3 && tar xfz -)
RUN curl --output /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3/apache-tomcat-8.0.21/webapps/uaa.war -L https://s3.amazonaws.com/bosh-dependencies/cloudfoundry-identity-uaa-2.0.3.war
RUN curl -L --output /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 && chmod +x /usr/local/bin/jq

ADD install-java.sh /tmp/install-java.sh
RUN chmod a+x /tmp/install-java.sh
RUN cd /tmp && ./install-java.sh && rm install-java.sh
ENV JAVA_HOME /usr/lib/jvm/zulu8.23.0.3-jdk8.0.144-linux_x64
ENV PATH $JAVA_HOME/bin:$PATH

RUN git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
RUN git config --global user.name "BOSH CI"

RUN date > /var/docker-image-timestamp
#---end main-base

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5072E1F5 && \
    echo "deb http://repo.mysql.com/apt/ubuntu/ xenial mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list

RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections

RUN echo 'mysql-community-server	mysql-community-server/root-pass	password password' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/re-root-pass	password password' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/data-dir	note' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/remove-data-dir	boolean	false' | debconf-set-selections

RUN apt-get update

RUN apt-get install -y mysql-server$DB_VERSION
RUN locale-gen en_US.UTF-8
