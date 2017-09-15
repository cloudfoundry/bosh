FROM bosh/main-base

# BOSH dependencies
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/pgdg.list && wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update
RUN apt-get install -y \
	mysql-client \
	postgresql-9.4 \
	postgresql-client-9.4 \
	&& apt-get clean

# mysql must be run as root
# mysql user: root/password
RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
RUN apt-get install -y mysql-server && apt-get clean
