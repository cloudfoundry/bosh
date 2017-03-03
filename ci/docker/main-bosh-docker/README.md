## main-bosh-docker image

Minimal image that contains:

- dependencies required to launch a BOSH Director using the Docker CPI within a container
- bosh v2 CLI
- Ruby
- Go

The started Director comes preconfigured with a default [cloud config](https://github.com/cloudfoundry/bosh-deployment/blob/master/docker/cloud-config.yml) and is optimized for Concourse usage.

`start-bosh` will produce artifacts in `/tmp/local-bosh/director` which are necessary to interact with the BOSH Director.
- `creds.yml` will contain the vars-store for the bosh deploy
- `env` will contain the environment variables necessary to target, authenticate, and interact with the bosh director
- `state.json` contains the state information for the director

A simple example usage:

```
#!/usr/bin/env bash

set -ex

start-bosh

source /tmp/local-bosh/director/env

bosh upload-stemcell ...
bosh -d cf deploy ...
```

`start-bosh` will also allow passing additional command line args into the `create-env` command that will be run. So, to start a customized director, you could use something like:

```
#!/usr/bin/env bash

set -ex

start-bosh -o /usr/local/bosh-deployment/uaa.yml -o /usr/local/bosh-deployment/local-bosh-release.yml -v local_bosh_release=/path/to/bosh.tgz

source /tmp/local-bosh/director/env

bosh upload-stemcell ...
bosh -d cf deploy ...
```
