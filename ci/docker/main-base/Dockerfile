FROM bosh/main-ruby-go

# BOSH dependencies
RUN apt-get update && apt-get install -y \
	libmariadbclient-dev \
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
ENV JAVA_HOME /usr/lib/jvm/zulu1.8.0_25-8.4.0.1-x86lx64
ENV PATH $JAVA_HOME/bin:$PATH

RUN git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
RUN git config --global user.name "BOSH CI"

RUN date > /var/docker-image-timestamp
