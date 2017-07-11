FROM bosh/main-bosh-docker

# mysql must be run as root
# mysql user: root/password
RUN echo 'mysql-server mysql-server/root_password password password' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password password' | debconf-set-selections
RUN apt-get update && apt-get install -y mysql-server ruby-dev build-essential && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf && \
  echo "max_connections = 400" >> /etc/mysql/mysql.conf.d/mysqld.cnf
