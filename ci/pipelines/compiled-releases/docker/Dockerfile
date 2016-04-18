FROM ubuntu:14.04

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

ADD install-dependencies.sh /tmp/install-dependencies.sh
RUN /tmp/install-dependencies.sh && rm /tmp/install-dependencies.sh
