FROM ubuntu:xenial

RUN apt-get clean && apt-get update && apt-get install -y locales

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

RUN apt-get -y upgrade
RUN apt-get install -y \
	build-essential \
	git \
	curl \
	wget \
	tar \
	libssl-dev \
	libreadline-dev \
	sqlite3 \
	libsqlite3-dev \
	dnsutils \
	xvfb \
	jq \
	realpath \
	libpq-dev \
	rsyslog \
	libcurl4-openssl-dev \
	&& apt-get clean

# Nokogiri dependencies
RUN apt-get install -y libxslt-dev libxml2-dev && apt-get clean

ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd /tmp && ./install-ruby.sh && rm install-ruby.sh

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH
ENV PATH /opt/rubies/ruby-2.6.3/bin:$PATH

# Database clients
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update
RUN apt-get install -y \
	mysql-client \
	postgresql-10 \
	postgresql-client-10 \
	&& apt-get clean
