FROM ubuntu:16.04

# Install Dependencies
RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
RUN apt-get update && apt-get -yq install \
    wget build-essential libmysqlclient-dev libpq-dev libsqlite3-dev git mysql-server

# Install Ruby
RUN wget -O ruby-install-0.7.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.7.0.tar.gz && \
    tar -xzvf ruby-install-0.7.0.tar.gz && \
    cd ruby-install-0.7.0/ && \
    make install
RUN ruby-install ruby-2.6.3
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
