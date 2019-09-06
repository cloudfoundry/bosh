FROM bosh/main-base

ARG DB_VERSION

ENV DEBIAN_FRONTEND noninteractive

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

RUN echo "deb http://archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse" >> /etc/apt/sources.list.d/mysql.list

RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections

RUN echo 'mysql-community-server	mysql-community-server/root-pass	password password' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/re-root-pass	password password' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/data-dir	note' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/remove-data-dir	boolean	false' | debconf-set-selections

RUN apt-get update

RUN apt-get install -y mysql-server$DB_VERSION
