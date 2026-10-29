## docker-cpi image

Minimal image that contains:

- dependencies required to launch a BOSH Director using the Docker CPI within a container
- bosh v2 CLI
- credhub CLI
- Ruby
- Go

The started Director comes preconfigured with a default [cloud config](https://github.com/cloudfoundry/bosh-deployment/blob/master/docker/cloud-config.yml) and is optimized for Concourse usage.
The cloud config's default network has the static IPs `10.245.0.11-10.245.0.64`.

UAA and CredHub are always enabled (`uaa.yml` and `credhub.yml` from
bosh-deployment are applied for you), so `((variables))` in deployment
manifests are generated and stored in CredHub. Do not pass `uaa.yml` or
`credhub.yml` to `start-bosh` yourself: they append releases and jobs, so
applying them twice makes `create-env` fail.

All releases the Director needs (bosh, bpm, uaa, credhub, os-conf,
bosh-docker-cpi) are baked into the image under `/usr/local/releases`, so
`create-env` does not download them. A baked-in release is only used when its
sha1 matches the one in the manifest; otherwise (for example with a newer
`BOSH_DEPLOYMENT_PATH`, or an ops file that swaps the release) it is
downloaded as usual.

`. start-bosh` will produce artifacts in `/tmp/local-bosh/director` which are necessary to interact with the BOSH Director.
- `creds.yml` will contain the vars-store for the bosh deploy
- `bosh-env` will contain the environment variables necessary to target, authenticate, and interact with the bosh director and CredHub (it also sources `docker-env`)
- `docker-env` will contain the environment variables for the docker daemon (see `start-docker` below)
- `ca.crt` and `credhub-ca.crt` contain the CA certificates for the Director and for CredHub/UAA
- `state.json` contains the state information for the director

It is necessary to run in the current shell so that the docker service can be
stopped on exit. Otherwise the concourse task may hang.

`start-bosh` and `bosh-env` turn off `set -x` while they handle credentials,
so sourcing them with `set -x` on doesn't print secrets.

A simple example usage:

```bash
#!/usr/bin/env bash

set -e

. start-bosh

source /tmp/local-bosh/director/bosh-env

bosh upload-stemcell ...
bosh -d cf deploy ...
credhub find
```

Besides the `BOSH_*` variables, `bosh-env` exports what the `credhub` CLI needs:

| Variable | Value |
|---|---|
| `CREDHUB_SERVER` | `https://10.245.0.3:8844` |
| `CREDHUB_CLIENT` | `credhub-admin` |
| `CREDHUB_SECRET` | the `credhub_admin_client_secret` from `creds.yml` |
| `CREDHUB_CA_CERT` | `/tmp/local-bosh/director/credhub-ca.crt` (CredHub and UAA CAs) |

`. start-bosh` also passes any additional command line args (ops files `-o`, variables `-v`, etc.) to the `bosh int` call that builds the director manifest, before `create-env` runs. So, to start a customized director, you could use something like:

```bash
#!/usr/bin/env bash

set -e

. start-bosh -o /usr/local/bosh-deployment/local-bosh-release.yml -v local_bosh_release=/path/to/bosh.tgz

source /tmp/local-bosh/director/bosh-env

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
