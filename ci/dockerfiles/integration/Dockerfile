# builds: bosh/integration:main
# used for running integration tests across ci

FROM bosh/main-ruby-go:main

RUN apt-get update && apt-get -yq install \
    build-essential locales git wget

# Install Dependencies
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8

# Java to start UAA
ADD install-java.sh /tmp/install-java.sh
RUN chmod a+x /tmp/install-java.sh
RUN cd /tmp && ./install-java.sh && rm install-java.sh
ENV JAVA_HOME /usr/lib/jvm/zulu8.23.0.3-jdk8.0.144-linux_x64
ENV PATH $JAVA_HOME/bin:$PATH
