FROM ubuntu:xenial

ADD install.sh /tmp/install.sh
RUN /tmp/install.sh && rm /tmp/install.sh

ADD install-ruby.sh /tmp/install-ruby.sh
RUN /tmp/install-ruby.sh && rm /tmp/install-ruby.sh

COPY --from=golang:1 /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go PATH=/usr/local/go/bin:$PATH

COPY bosh /usr/local/bin/
RUN chmod +x /usr/local/bin/bosh

COPY bosh-deployment /usr/local/bosh-deployment/
RUN \
  BOSH_RELEASE_URL="$(bosh int /usr/local/bosh-deployment/bosh.yml --path /releases/name=bosh/url)" \
  BPM_RELEASE_URL="$(bosh int /usr/local/bosh-deployment/bosh.yml --path /releases/name=bpm/url)" && \
  curl -o /usr/local/bosh.tgz "$BOSH_RELEASE_URL" && \
  curl -o /usr/local/bpm.tgz "$BPM_RELEASE_URL" && \
  apt-get update && apt-get install -y jq gcc

COPY local-releases.yml /usr/local/local-releases.yml
COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh
