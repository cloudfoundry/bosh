#!/usr/bin/env bash

set -e

function generate_certs() {
  local certs_dir
  certs_dir="${1}"

  pushd "${certs_dir}" > /dev/null
    cat <<EOF > ./bosh-vars.yml
---
variables:
- name: docker_ca
  type: certificate
  options:
    is_ca: true
    common_name: ca
- name: docker_tls
  type: certificate
  options:
    extended_key_usage: [server_auth]
    common_name: $OUTER_CONTAINER_IP
    alternative_names: [$OUTER_CONTAINER_IP]
    ca: docker_ca
- name: client_docker_tls
  type: certificate
  options:
    extended_key_usage: [client_auth]
    common_name: $OUTER_CONTAINER_IP
    alternative_names: [$OUTER_CONTAINER_IP]
    ca: docker_ca
EOF

   bosh int ./bosh-vars.yml --vars-store=./certs.yml
   bosh int ./certs.yml --path=/docker_ca/ca > ./ca.pem
   bosh int ./certs.yml --path=/docker_tls/certificate > ./server-cert.pem
   bosh int ./certs.yml --path=/docker_tls/private_key > ./server-key.pem
   bosh int ./certs.yml --path=/client_docker_tls/certificate > ./cert.pem
   bosh int ./certs.yml --path=/client_docker_tls/private_key > ./key.pem
    # generate certs in json format
    #
   ruby -e 'puts File.read("./ca.pem").split("\n").join("\\n")' > $certs_dir/ca_json_safe.pem
   ruby -e 'puts File.read("./cert.pem").split("\n").join("\\n")' > $certs_dir/client_certificate_json_safe.pem
   ruby -e 'puts File.read("./key.pem").split("\n").join("\\n")' > $certs_dir/client_private_key_json_safe.pem
  popd > /dev/null
}

function sanitize_cgroups() {
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  mount -o remount,rw /sys/fs/cgroup

  sed -e 1d /proc/cgroups | while read sys hierarchy num enabled; do
    if [ "$enabled" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    grouping="$(cat /proc/self/cgroup | cut -d: -f2 | grep "\\<$sys\\>")"
    if [ -z "$grouping" ]; then
      # subsystem not mounted anywhere; mount it on its own
      grouping="$sys"
    fi

    mountpoint="/sys/fs/cgroup/$grouping"

    mkdir -p "$mountpoint"

    # clear out existing mount to make sure new one is read-write
    if mountpoint -q "$mountpoint"; then
      umount "$mountpoint"
    fi

    mount -n -t cgroup -o "$grouping" cgroup "$mountpoint"

    if [ "$grouping" != "$sys" ]; then
      if [ -L "/sys/fs/cgroup/$sys" ]; then
        rm "/sys/fs/cgroup/$sys"
      fi

      ln -s "$mountpoint" "/sys/fs/cgroup/$sys"
    fi
  done
}

function stop_docker() {
  service docker stop
}

function start_docker() {
  local certs_dir
  certs_dir="${1}"
  # docker will fail starting with the new iptables. it throws:
  # iptables v1.8.7 (nf_tables): Could not fetch rule set generation id: ....
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  generate_certs "${certs_dir}"
  mkdir -p /var/log
  mkdir -p /var/run

  sanitize_cgroups

  # ensure systemd cgroup is present
  mkdir -p /sys/fs/cgroup/systemd
  if ! mountpoint -q /sys/fs/cgroup/systemd ; then
    mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
  fi

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi

  local mtu
  mtu=$(cat "/sys/class/net/$(ip route get 169.254.169.254|awk '{ print $5 }')/mtu")

  [[ ! -d /etc/docker ]] && mkdir /etc/docker
  cat <<EOF > /etc/docker/daemon.json
{
  "hosts": ["${DOCKER_HOST}"],
  "tls": true,
  "tlscert": "${certs_dir}/server-cert.pem",
  "tlskey": "${certs_dir}/server-key.pem",
  "tlscacert": "${certs_dir}/ca.pem",
  "mtu": ${mtu},
  "data-root": "/scratch/docker",
  "tlsverify": true
}
EOF

  trap stop_docker EXIT

  service docker start

  export DOCKER_TLS_VERIFY=1
  export DOCKER_CERT_PATH="${certs_dir}"

  rc=1
  for i in $(seq 1 100); do
    echo "waiting for docker to come up... (${i})"
    sleep 1
    set +e
    docker info
    rc=$?
    set -e
    if [ "$rc" -eq "0" ]; then
        break
    fi
  done

  if [ "$rc" -ne "0" ]; then
    exit 1
  fi

  echo "${certs_dir}"
}

function main() {
  OUTER_CONTAINER_IP=$(
    ip addr \
    | grep 'inet ' \
    | grep -v -E ' (127\.|172\.|10\.245)' \
    | cut -d/ -f 1 \
    | cut -d' ' -f6
  )
  export OUTER_CONTAINER_IP

  if [[ "${OUTER_CONTAINER_IP}" == *$'\n'* ]] ; then
    echo "OUTER_CONTAINER_IP had more than one ip: '${OUTER_CONTAINER_IP}'" >&2
    exit 1
  fi

  export DOCKER_HOST="tcp://${OUTER_CONTAINER_IP}:4243"

  local certs_dir
  certs_dir=$(mktemp -d)
  start_docker "${certs_dir}"

  local local_bosh_dir
  local_bosh_dir="/tmp/local-bosh/director"

  local docker_network_name="director_network"
  if docker network ls | grep -q "${docker_network_name}"; then
    echo "A docker network named '${docker_network_name}' already exists, skipping creation" >&2
  else
    docker network create -d bridge --subnet=10.245.0.0/16 "${docker_network_name}"
  fi

  pushd "${BOSH_DEPLOYMENT_PATH:-/usr/local/bosh-deployment}" > /dev/null
      export BOSH_DIRECTOR_IP="10.245.0.3"
      export BOSH_ENVIRONMENT="docker-director"

      mkdir -p ${local_bosh_dir}

      additional_ops_files=""
      if [ "$(lsb_release -cs)" != "jammy" ]; then
        additional_ops_files="-o /usr/local/noble-updates.yml"
      fi

      command bosh int bosh.yml \
        -o docker/cpi.yml \
        -o jumpbox-user.yml \
        -o /usr/local/local-releases.yml \
        ${additional_ops_files} \
        -v director_name=docker \
        -v internal_cidr=10.245.0.0/16 \
        -v internal_gw=10.245.0.1 \
        -v internal_ip="${BOSH_DIRECTOR_IP}" \
        -v docker_host="${DOCKER_HOST}" \
        -v network=director_network \
        -v docker_tls="{\"ca\": \"$(cat "${certs_dir}/ca_json_safe.pem")\",\"certificate\": \"$(cat "${certs_dir}/client_certificate_json_safe.pem")\",\"private_key\": \"$(cat "${certs_dir}/client_private_key_json_safe.pem")\"}" \
        ${@} > "${local_bosh_dir}/bosh-director.yml"

      command bosh create-env "${local_bosh_dir}/bosh-director.yml" \
              --vars-store="${local_bosh_dir}/creds.yml" \
              --state="${local_bosh_dir}/state.json"

      bosh int "${local_bosh_dir}/creds.yml" --path /director_ssl/ca > "${local_bosh_dir}/ca.crt"
      bosh -e "${BOSH_DIRECTOR_IP}" --ca-cert "${local_bosh_dir}/ca.crt" alias-env "${BOSH_ENVIRONMENT}"

      bosh_client_secret="$(bosh int "${local_bosh_dir}/creds.yml" --path /admin_password)"

      cat <<EOF > "${local_bosh_dir}/env"
      export BOSH_ENVIRONMENT="${BOSH_ENVIRONMENT}"
      export BOSH_CLIENT=admin
      export BOSH_CLIENT_SECRET=${bosh_client_secret}
      export BOSH_CA_CERT="${local_bosh_dir}/ca.crt"

EOF
      source "${local_bosh_dir}/env"

      bosh -n update-cloud-config docker/cloud-config.yml -v network=director_network

  popd > /dev/null
}

main ${@}
