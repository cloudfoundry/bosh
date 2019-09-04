FROM bosh/main-base

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

# BOSH dependencies
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update
RUN apt-get install -y \
	mysql-client \
	postgresql-10 \
	postgresql-client-10 \
	&& apt-get clean

# mysql must be run as root
# mysql user: root/password
RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
RUN apt-get install -y mysql-server && apt-get clean
