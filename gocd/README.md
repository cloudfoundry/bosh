# BOSH Containerized Continuous Deployment

This module is a set of scripts to run the BOSH unit and integration tests in linux containers. It's primarily meant to be run with GoCD, but can also be run locally on linux machines or inside a linux VM.

The Pivotal BOSH team primarily uses Jenkins for its continuous integration. These containers, however, are used for push-triggered testing of the development branch.

There are currently two GoCD pipelines:

## bosh pipeline
This pipeline runs unit and integration tests inside a docker container.

## docker pipeline
This pieline creates and uploads the docker image used by the bosh pipeline.

## Usage
To run tests locally, follow these steps...

1. Bring up the VM

```
vagrant up --provider virtualbox
```

2. SSH into the VM

```
vagrant ssh
```

3. (Optional) Build the docker image from the Dockerfile

```
docker build -t docker.gocd.cf-app.com:5000/bosh-container /vagrant
```

4. (Optional) Push the docker image to the Pivotal GoCD Docker Registry

```
docker push docker.gocd.cf-app.com:5000/bosh-container
```

5. Run the unit tests in the docker container (downloads the docker image if not built/cached locally)

```
cd /opt/bosh
run-in-container.sh /opt/bosh/gocd/bosh/tests/unit/job.sh

```

6. Run the integration tests in the docker container (downloads the docker image if not built/cached locally)

```
cd /opt/bosh
run-in-container.sh /opt/bosh/gocd/bosh/tests/unit/job.sh

```

7. Destroy the VM

```
vagrant destroy bosh-docker-builder --force
```
