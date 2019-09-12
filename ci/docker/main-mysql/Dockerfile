# FROM bosh/main-base

# ARG DB_VERSION

# ENV DEBIAN_FRONTEND noninteractive

# ENV LANG en_US.UTF-8
# ENV LC_ALL en_US.UTF-8
# RUN locale-gen en_US.UTF-8

# RUN echo "deb http://archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse" >> /etc/apt/sources.list.d/mysql.list

# RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
# RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections

# RUN echo 'mysql-community-server	mysql-community-server/root-pass	password password' | debconf-set-selections
# RUN echo 'mysql-community-server	mysql-community-server/re-root-pass	password password' | debconf-set-selections
# RUN echo 'mysql-community-server	mysql-community-server/data-dir	note' | debconf-set-selections
# RUN echo 'mysql-community-server	mysql-community-server/remove-data-dir	boolean	false' | debconf-set-selections

# RUN apt-get update

# RUN apt-get install -y mysql-server$DB_VERSION

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

# Install Golang
COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH
