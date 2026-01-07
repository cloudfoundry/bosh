ARG BASE_IMAGE
FROM $BASE_IMAGE

RUN apt-get update -y \
    && apt-get -y install --no-install-recommends \
        gpg-agent \
        software-properties-common \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        apparmor \
        ca-certificates \
        iproute2 \
        iptables \
        zlib1g-dev

COPY bosh-deployment /usr/local/bosh-deployment/
RUN \
  cd /usr/local && \
  mkdir releases && \
  bosh int bosh-deployment/bosh.yml \
    -o bosh-deployment/bosh-lite.yml \
    -o bosh-deployment/warden/cpi.yml \
    -o bosh-deployment/uaa.yml \
    -o bosh-deployment/credhub.yml > /tmp/manifest-with-releases.yml && \
  BOSH_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=bosh/url)" \
  BPM_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=bpm/url)" \
  GARDEN_RUNC_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=garden-runc/url)" \
  BOSH_WARDEN_CPI_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=bosh-warden-cpi/url)" \
  OS_CONF_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=os-conf/url)" \
  UAA_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=uaa/url)" \
  CREDHUB_RELEASE_URL="$(bosh int /tmp/manifest-with-releases.yml --path /releases/name=credhub/url)" && \
  wget -q -O /usr/local/releases/bosh.tgz "${BOSH_RELEASE_URL}" && \
  wget -q -O /usr/local/releases/bpm.tgz "${BPM_RELEASE_URL}" && \
  wget -q -O /usr/local/releases/garden-runc.tgz "${GARDEN_RUNC_RELEASE_URL}" && \
  wget -q -O /usr/local/releases/warden-cpi.tgz "${BOSH_WARDEN_CPI_RELEASE_URL}" && \
  wget -q -O /usr/local/releases/os-conf.tgz "${OS_CONF_RELEASE_URL}" && \
  wget -q -O /usr/local/releases/uaa.tgz "${UAA_RELEASE_URL}" && \
  wget -q -O /usr/local/releases/credhub.tgz "${CREDHUB_RELEASE_URL}"

COPY local-releases.yml /usr/local/local-releases.yml
COPY start-bosh.sh /usr/local/bin/start-bosh
RUN chmod +x /usr/local/bin/start-bosh

RUN mkdir -p /var/vcap/sys/log/warden_cpi/
RUN useradd -ms /bin/bash vcap

COPY template-renderer.rb /tmp/template-renderer.rb
COPY install-garden.rb /tmp/install-garden.rb
RUN ruby /tmp/install-garden.rb /usr/local/releases/garden-runc.tgz
RUN rm -rf /tmp/*
