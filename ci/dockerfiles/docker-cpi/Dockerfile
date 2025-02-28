# this image builds bosh/docker-cpi
# it is used across ci to start a bosh in a docker container
FROM bosh/integration:main

RUN docker_gpg="/etc/apt/trusted.gpg.d/docker.gpg" \
    && curl --show-error -sL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o "${docker_gpg}" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=${docker_gpg}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      apt-transport-https \
      ca-certificates \
      docker-ce \
      iproute2 \
      xfsprogs

# https://github.com/docker/cli/issues/4807
# As of 02/01/2024 a change in the "/etc/init.d/docker" script shipped with docker v25
# is preventing the cpi image to work.
# when start-bosh runs `service docker start` it errors with:
# "/etc/init.d/docker: 62: ulimit: error setting limit (Invalid argument)"
# disable resetting ulimit. Pre v25 the script contained `ulimit -n 1048576`
# the default in our base image is:
# ulimit | grep file
# `open files                          (-n) 1048576`
# so it was a noOp..
# running `ulimit -Hn 1048576` will succeed.. The issue happens when we want to raise the ulimit.
RUN sed -i 's/\(ulimit -Hn [0-9]*\)/#\1/' /etc/init.d/docker

COPY bosh-deployment /usr/local/bosh-deployment/
RUN curl -o /usr/local/bosh.tgz "$(bosh int /usr/local/bosh-deployment/bosh.yml --path /releases/name=bosh/url)" \
    && curl -o /usr/local/bpm.tgz "$(bosh int /usr/local/bosh-deployment/bosh.yml --path /releases/name=bpm/url)"

COPY local-releases.yml /usr/local/local-releases.yml
COPY noble-updates.yml /usr/local/noble-updates.yml
COPY start-bosh.sh /usr/local/bin/start-bosh

RUN chmod +x /usr/local/bin/start-bosh
