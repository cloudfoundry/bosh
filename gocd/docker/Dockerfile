FROM ubuntu

RUN apt-get update
RUN apt-get -y upgrade; apt-get clean

RUN apt-get install -y build-essential; apt-get clean
RUN apt-get install -y git; apt-get clean
RUN apt-get install -y curl; apt-get clean
RUN apt-get install -y wget; apt-get clean
RUN apt-get install -y tar; apt-get clean

RUN apt-get install -y libssl-dev; apt-get clean
RUN apt-get install -y libreadline-dev; apt-get clean
RUN apt-get install -y dnsutils; apt-get clean
RUN apt-get install -y xvfb; apt-get clean
# RUN apt-get install -y openssh-server; apt-get clean

ADD install-ruby.sh /tmp/install-ruby.sh
RUN cd /tmp; ./install-ruby.sh; rm install-ruby.sh
