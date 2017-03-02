FROM bosh/main-ruby-go

ADD ./install-docker.sh /tmp/install-docker.sh
RUN /tmp/install-docker.sh
RUN rm /tmp/install-docker.sh

ADD ./install-bosh-dependencies.sh /tmp/install-bosh-dependencies.sh
RUN /tmp/install-bosh-dependencies.sh
RUN rm /tmp/install-bosh-dependencies.sh

COPY start-bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-bosh
