FROM ubuntu:jammy

ADD install.sh /tmp/install.sh
RUN /tmp/install.sh && rm /tmp/install.sh

ADD install-ruby.sh /tmp/install-ruby.sh
RUN /tmp/install-ruby.sh && rm /tmp/install-ruby.sh
ENV PATH /opt/rubies/ruby-3.1.2/bin:$PATH

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/

COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh
