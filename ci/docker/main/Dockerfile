FROM bosh/main-ruby-go

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

# BOSH dependencies
RUN apt-get update && apt-get install -y \
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
