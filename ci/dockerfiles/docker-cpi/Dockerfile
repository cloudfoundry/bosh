# this image builds bosh/docker-cpi
# it is used across ci to start a bosh in a docker container
FROM bosh/integration:main

ADD install.sh /tmp/install.sh
RUN /tmp/install.sh && rm /tmp/install.sh

COPY bosh-deployment /usr/local/bosh-deployment/
RUN \
  BOSH_RELEASE_URL="$(bosh int /usr/local/bosh-deployment/bosh.yml --path /releases/name=bosh/url)" \
  BPM_RELEASE_URL="$(bosh int /usr/local/bosh-deployment/bosh.yml --path /releases/name=bpm/url)" && \
  curl -o /usr/local/bosh.tgz "$BOSH_RELEASE_URL" && \
  curl -o /usr/local/bpm.tgz "$BPM_RELEASE_URL" && \
  apt-get update && apt-get install -y xfsprogs

COPY local-releases.yml /usr/local/local-releases.yml
COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh

ADD ./install-garden.sh /tmp/install-garden.sh
RUN /tmp/install-garden.sh
RUN rm /tmp/install-garden.sh
COPY start-garden.sh /usr/local/bin/start-garden
RUN chmod +x /usr/local/bin/start-garden

