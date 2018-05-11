FROM bosh/main-base

ARG DB_VERSION

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5 && \
    echo "deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7" | tee -a /etc/apt/sources.list.d/mysql.list

RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections

RUN echo 'mysql-community-server	mysql-community-server/root-pass	password password' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/re-root-pass	password password' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/data-dir	note' | debconf-set-selections
RUN echo 'mysql-community-server	mysql-community-server/remove-data-dir	boolean	false' | debconf-set-selections

RUN apt-get update

RUN sudo apt-get install -y  mysql-server$DB_VERSION
