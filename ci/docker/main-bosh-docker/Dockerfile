FROM ubuntu:xenial

ADD install.sh /tmp/install.sh
RUN /tmp/install.sh && rm /tmp/install.sh

COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh
