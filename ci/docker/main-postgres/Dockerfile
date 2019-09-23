FROM ubuntu:xenial

ARG DB_VERSION

# To build all gems and install ruby
RUN apt update && apt -yq install \
    wget build-essential libmysqlclient-dev libpq-dev libsqlite3-dev git

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt update

RUN apt install -y \
	postgresql-$DB_VERSION \
	postgresql-client-$DB_VERSION \
	&& apt clean

ADD trust_pg_hba.conf /tmp/pg_hba.conf
RUN cp /tmp/pg_hba.conf /etc/postgresql/$DB_VERSION/main/pg_hba.conf

# Install Ruby
ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd /tmp && ./install-ruby.sh && rm install-ruby.sh
ENV PATH /opt/rubies/ruby-2.6.3/bin:/opt/rubies/ruby-2.4.5/bin:$PATH

# Java to start UAA
ADD install-java.sh /tmp/install-java.sh
RUN chmod a+x /tmp/install-java.sh
RUN cd /tmp && ./install-java.sh && rm install-java.sh
ENV JAVA_HOME /usr/lib/jvm/zulu8.23.0.3-jdk8.0.144-linux_x64
ENV PATH $JAVA_HOME/bin:$PATH

# Install Golang
COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH
