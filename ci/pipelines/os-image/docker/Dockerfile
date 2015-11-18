FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN apt-get update
RUN apt-get -y upgrade; apt-get clean

RUN apt-get install -y build-essential zlib1g-dev libssl-dev
RUN apt-get install -y git curl wget tar
RUN apt-get clean

# ...vagrant:
# package manager provides Vagrant 1.4.3... too old for vagrant-aws
ENV VAGRANT_PKG vagrant_1.6.5_x86_64.deb
ENV VAGRANT_SHA e2c7af6d032ac551ebd6399265cb9cb64402c9fb96a12289161b7f67afada28a
RUN cd /tmp \
    && wget -q https://dl.bintray.com/mitchellh/vagrant/${VAGRANT_PKG} \
    && echo "${VAGRANT_SHA} ${VAGRANT_PKG}" > sha256sum.txt \
    && sha256sum -c sha256sum.txt && rm sha256sum.txt \
    && dpkg -i ${VAGRANT_PKG} \
    && rm ${VAGRANT_PKG}
RUN vagrant plugin install vagrant-aws
RUN apt-get clean

# ...ruby
ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd tmp; ./install-ruby.sh; rm install-ruby.sh

# ...hijacking/debugging
RUN apt-get install -y lsof psmisc strace
