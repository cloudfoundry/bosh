## docker-cpi image

Minimal image that contains:

- dependencies required to launch a BOSH Director using the Docker CPI within a container
- bosh v2 CLI
- Ruby
- Go

The started Director comes preconfigured with a default [cloud config](https://github.com/cloudfoundry/bosh-deployment/blob/master/docker/cloud-config.yml) and is optimized for Concourse usage.

`. start-bosh` will produce artifacts in `/tmp/local-bosh/director` which are necessary to interact with the BOSH Director.
- `creds.yml` will contain the vars-store for the bosh deploy
- `env` will contain the environment variables necessary to target, authenticate, and interact with the bosh director
- `state.json` contains the state information for the director

It is necessary to run in the current shell so that the docker service can be
stopped on exit. Otherwise the concourse task may hang.

A simple example usage:

```bash
#!/usr/bin/env bash

set -ex

. start-bosh

source /tmp/local-bosh/director/env

bosh upload-stemcell ...
bosh -d cf deploy ...
```

`. start-bosh` will also allow passing additional command line args into the `create-env` command that will be run. So, to start a customized director, you could use something like:

```bash
#!/usr/bin/env bash

set -ex

. start-bosh -o /usr/local/bosh-deployment/uaa.yml -o /usr/local/bosh-deployment/local-bosh-release.yml -v local_bosh_release=/path/to/bosh.tgz

source /tmp/local-bosh/director/env

bosh upload-stemcell ...
bosh -d cf deploy ...
```

## `. start-docker`

For "I need a docker daemon, not a director". `start-bosh` sources it; anything
that only wants a dockerd in a Concourse container can too. It exports:

| Variable | Value |
|---|---|
| `OUTER_CONTAINER_IP` | the container's `eth0` address |
| `DOCKER_HOST` | `tcp://${OUTER_CONTAINER_IP}:4243` |
| `DOCKER_TLS_VERIFY` | `1` |
| `DOCKER_CERT_PATH` | a `mktemp -d` holding the generated CA and client certs |
| `DOCKER_NETWORK_NAME` | `director_network` |
| `DOCKER_NETWORK_CIDR` | `10.245.0.0/16` |
| `DOCKER_TLS_JSON` | path to a `{ca, certificate, private_key}` JSON blob |

The network name and CIDR are fixed: `start-bosh` places the director's gateway
and IP inside that CIDR.

Like `start-bosh` it must be sourced, so that the daemon runs in the current
shell's process group and can be stopped on exit.

```bash
#!/usr/bin/env bash

set -ex

trap 'service docker stop' EXIT

. start-docker

docker run ...
```
