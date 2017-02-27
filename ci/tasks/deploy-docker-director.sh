#!/usr/bin/env bash

set -ex
source bosh-src/ci/tasks/docker_utils.sh
source /etc/profile.d/chruby.sh
chruby 2.3.1

mv ./bosh-cli/*bosh-cli-*-linux-amd64 /usr/local/bin/bosh
chmod +x /usr/local/bin/bosh

export OUTER_CONTAINER_IP=$(ruby -rsocket -e 'puts Socket.ip_address_list
                        .reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6? }
                        .map { |addr| addr.ip_address }')

export DOCKER_HOST="tcp://${OUTER_CONTAINER_IP}:4243"

certs_dir=$(mktemp -d)
start_docker $certs_dir

docker network create -d bridge --subnet=10.245.0.0/16 director_network

pushd bosh-deployment
    bosh create-env bosh.yml \
      -o docker/cpi.yml \
      -o jumpbox-user.yml \
      -o local-bosh-release.yml \
      --state=./state.json \
      --vars-store=./creds.yml\
      -v director_name=docker \
      -v internal_cidr=10.245.0.0/16 \
      -v internal_gw=10.245.0.1 \
      -v internal_ip=10.245.0.3 \
      -v docker_host=${DOCKER_HOST} \
      -v network=director_network \
      -v docker_tls="{\"ca\": \"$(cat ${certs_dir}/ca_json_safe.pem)\",\"certificate\": \"$(cat ${certs_dir}/client_certificate_json_safe.pem)\",\"private_key\": \"$(cat ${certs_dir}/client_private_key_json_safe.pem)\"}" \
      -v local_bosh_release=../bosh-dev-release/bosh-dev-release.tgz

    bosh -e 10.245.0.3 --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca) alias-env bosh-1

    export BOSH_CLIENT=admin
    export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`

    bosh int creds.yml --path /jumpbox_ssh/private_key > $certs_dir/jumpbox_ssh_key.pem
    chmod 400 $certs_dir/jumpbox_ssh_key.pem
popd

# pushd bosh-src/some/path/to/ginkgo/tests
# ginkgo -r things/that/test
