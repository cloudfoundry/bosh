FROM bosh/main-ruby-go

# BOSH dependencies {
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
# }

# UAA dependencies {
RUN \
	mkdir -p /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3 \
	&& cd /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3 \
	&& curl -L https://s3.amazonaws.com/bosh-dependencies/apache-tomcat-8.0.21.tar.gz | tar xfz - \
	&& curl --output /tmp/integration-uaa/cloudfoundry-identity-uaa-2.0.3/apache-tomcat-8.0.21/webapps/uaa.war \
		-L https://s3.amazonaws.com/bosh-dependencies/cloudfoundry-identity-uaa-2.0.3.war \
	&& curl -L --output /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
	&& chmod +x /usr/local/bin/jq

# install java {
RUN \
	export PACKAGE_NAME="zulu8.23.0.3-jdk8.0.144-linux_x64.tar.gz" \
	&& export PACKAGE_MD5="6ecd67688407b9f7e45c2736f003398b" \
	&& export PACKAGE_TMP="/tmp/${PACKAGE_NAME}" \
	&& export PACKAGE_URL="http://cdn.azul.com/zulu/bin/${PACKAGE_NAME}" \
	&& export INSTALL_PREFIX="/usr/lib/jvm" \
	&& wget -O $PACKAGE_TMP --continue $PACKAGE_URL \
	&& (echo "${PACKAGE_MD5}  ${PACKAGE_TMP}" | md5sum -c -) \
	&& mkdir -p "${INSTALL_PREFIX}" \
	&& tar xf "${PACKAGE_TMP}" -C "${INSTALL_PREFIX}" \
	&& rm "${PACKAGE_TMP}"
# }

ENV JAVA_HOME /usr/lib/jvm/zulu8.23.0.3-jdk8.0.144-linux_x64
ENV PATH $JAVA_HOME/bin:$PATH

RUN \
	git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io" \
	&& git config --global user.name "BOSH CI"

RUN date > /var/docker-image-timestamp
# }
