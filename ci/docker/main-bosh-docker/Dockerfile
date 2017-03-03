FROM bosh/main-ruby-go

ADD ./install-docker.sh /tmp/install-docker.sh
RUN /tmp/install-docker.sh
RUN rm /tmp/install-docker.sh

COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-bosh
