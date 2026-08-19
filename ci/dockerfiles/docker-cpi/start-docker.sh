#!/usr/bin/env bash
set -eu -o pipefail

# Brings up a docker daemon inside a Concourse container and exports everything
# a caller needs to talk to it:
#
#   OUTER_CONTAINER_IP  DOCKER_HOST  DOCKER_TLS_VERIFY  DOCKER_CERT_PATH
#   DOCKER_NETWORK_NAME  DOCKER_NETWORK_CIDR  DOCKER_TLS_JSON
#
# Must be sourced, not executed: the exports and the daemon's process group both
# need to live in the caller's shell.

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
   ruby -e 'puts File.read("./ca.pem").split("\n").join("\\n")' > "${certs_dir}/ca_json_safe.pem"
   ruby -e 'puts File.read("./cert.pem").split("\n").join("\\n")' > "${certs_dir}/client_certificate_json_safe.pem"
   ruby -e 'puts File.read("./key.pem").split("\n").join("\\n")' > "${certs_dir}/client_private_key_json_safe.pem"
  popd > /dev/null
}

function sanitize_cgroups() {
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    # cgroups v2: enable nesting (based on moby/moby hack/dind)
    mkdir -p /sys/fs/cgroup/init
    # Loop to handle races from concurrent process creation (e.g. docker exec)
    while ! {
      xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || :
      sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
        > /sys/fs/cgroup/cgroup.subtree_control
    }; do true; done
    return
  fi

  mount -o remount,rw /sys/fs/cgroup

  sed -e 1d /proc/cgroups | while read -r sys enabled; do
    if [ "$enabled" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    grouping="$(cut -d: -f2 < /proc/self/cgroup | grep "\\<$sys\\>")"
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

function start_docker() {
  local certs_dir
  certs_dir="${1}"
  generate_certs "${certs_dir}"
  mkdir -p /var/log
  mkdir -p /var/run

  # Raise inotify limits so nested containers running systemd don't exhaust
  # file descriptors. Systemd and containerd's cgroup-v2 event monitor both
  # use inotify; the default max_user_instances (128) was too low.
  sysctl -w fs.inotify.max_user_instances=1024
  sysctl -w fs.inotify.max_user_watches=524288
  sysctl -w net.ipv4.ip_forward=1

  sanitize_cgroups

  # systemd inside nested Docker containers requires shared mount propagation
  mount --make-rshared /

  # ensure systemd cgroup is present (cgroups v1 only)
  if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
    mkdir -p /sys/fs/cgroup/systemd
    if ! mountpoint -q /sys/fs/cgroup/systemd ; then
      mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
    fi
  fi

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi

  gcp_internal_dns="169.254.169.254"
  local mtu
  mtu=$(cat "/sys/class/net/$(ip route get "${gcp_internal_dns}"|awk '{ print $5 }')/mtu")

  [[ ! -d /etc/docker ]] && mkdir /etc/docker
  cat <<EOF > /etc/docker/daemon.json
{
  "hosts": ["${DOCKER_HOST}"],
  "tls": true,
  "tlscert": "${certs_dir}/server-cert.pem",
  "tlskey": "${certs_dir}/server-key.pem",
  "tlscacert": "${certs_dir}/ca.pem",
  "mtu": ${mtu},
  "dns": ["${gcp_internal_dns}"],
  "data-root": "/scratch/docker",
  "tlsverify": true,
  "ip-forward-no-drop": true
}
EOF

  service docker start

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

function start_docker_main() {
  OUTER_CONTAINER_IP=$(
    ip addr \
    | grep 'inet ' \
    | grep eth0 \
    | cut -d/ -f 1 \
    | cut -d' ' -f6
  )
  export OUTER_CONTAINER_IP

  if [[ "${OUTER_CONTAINER_IP}" == *$'\n'* ]] ; then
    echo "OUTER_CONTAINER_IP had more than one ip: '${OUTER_CONTAINER_IP}'" >&2
    exit 1
  fi

  local certs_dir
  certs_dir=$(mktemp -d)

  local local_bosh_dir
  local_bosh_dir="/tmp/local-bosh/director"
  mkdir -p ${local_bosh_dir}

  docker_env_file="${local_bosh_dir}/docker-env"
  {
    echo "export DOCKER_HOST=\"tcp://${OUTER_CONTAINER_IP}:4243\""
    echo "export DOCKER_TLS_VERIFY=\"1\""
    echo "export DOCKER_CERT_PATH=\"${certs_dir}\""
  } > "${docker_env_file}"
  echo "Source '${docker_env_file}' to run docker" >&2
  # shellcheck disable=SC1090
  source "${docker_env_file}"

  start_docker "${certs_dir}"

  # Fixed, not overridable: start-bosh's internal_gw and BOSH_DIRECTOR_IP are
  # addresses within this CIDR.
  export DOCKER_NETWORK_NAME="director_network"
  export DOCKER_NETWORK_CIDR="10.245.0.0/16"
  if docker network ls --format '{{.Name}}' | grep -qx "${DOCKER_NETWORK_NAME}"; then
    echo "A docker network named '${DOCKER_NETWORK_NAME}' already exists, skipping creation" >&2
  else
    docker network create -d bridge --subnet="${DOCKER_NETWORK_CIDR}" "${DOCKER_NETWORK_NAME}"
  fi

  export DOCKER_TLS_JSON="${local_bosh_dir}/docker_tls.json"
  cat <<EOF > "${DOCKER_TLS_JSON}"
{
  "ca": "$(cat "${certs_dir}/ca_json_safe.pem")",
  "certificate": "$(cat "${certs_dir}/client_certificate_json_safe.pem")",
  "private_key": "$(cat "${certs_dir}/client_private_key_json_safe.pem")"
}
EOF
}

# Called bare, not with ${@}: when sourced, $@ is the caller's args
# (start-bosh's create-env flags), which are not ours to consume.
start_docker_main
