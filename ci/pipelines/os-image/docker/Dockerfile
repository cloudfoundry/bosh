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
RUN cd /tmp && wget -q https://dl.bintray.com/mitchellh/vagrant/vagrant_1.6.5_x86_64.deb && dpkg -i vagrant_1.6.5_x86_64.deb
RUN apt-get install -y git curl wget tar vagrant
RUN vagrant plugin install vagrant-aws
RUN apt-get clean

# ...ruby
ADD install-ruby.sh /tmp/install-ruby.sh
RUN chmod a+x /tmp/install-ruby.sh
RUN cd tmp; ./install-ruby.sh; rm install-ruby.sh

# ...hijacking/debugging
RUN apt-get install -y lsof psmisc strace
