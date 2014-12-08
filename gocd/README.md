# BOSH Containerized Continuous Deployment

This module is a set of scripts to run the BOSH unit and integration tests in linux containers. It's primarily meant to be run with GoCD, but can also be run locally on linux machines or inside a linux VM.


## Usage

To run tests locally, follow these steps...

1. (If running in VM) Bring up the VM
    
    ```
    # if behind a proxy, set http_proxy, https_proxy and no_proxy first
    export http_proxy=http://user:pwd@myproxy.example.com:8080
    export https_proxy=http://user:pwd@myproxy.example.com:8080
    export no_proxy=localhost
    cd gocd/docker
    vagrant up --provider virtualbox
    # if behind a proxy, reload to propagate settings to docker in VM
    vagrant reload
    ```

2. (If running in VM) SSH into the VM
    
    ```
    vagrant ssh
    ```

3. Pull the docker container from Docker Hub
    
    ```
    docker pull bosh/integration
    ```

4. Copy the mounted bosh dir (so that it can chown and write to it)
    ```
    sudo cp -r /opt/bosh /opt/bosh-copy
    cd /opt/bosh-copy
    ```

5. Select which version of ruby to use
    1. `export RUBY_VERSION=2.1.2`
    2. `export RUBY_VERSION=1.9.3`

6. (Optional) Select which database to use
    1. `export DB=postgres` (default)
    2. `export DB=mysql`

4. Run the unit tests in the docker container (downloads the docker image if not built/cached locally)
    
    ```
    gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/unit/job.sh
    ```

5. Run the integration tests in the docker container (downloads the docker image if not built/cached locally)
    
    ```
    gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/integration/job.sh
    ```

6. (If running in VM) Destroy the VM
    
    ```
    vagrant destroy bosh-docker-builder --force
    ```


## GoCD Pipelines

The Pivotal BOSH team primarily uses Jenkins for its continuous integration. These containers, however, are used for push-triggered testing of the [develop branch](https://github.com/cloudfoundry/bosh/tree/develop).

There are currently two GoCD pipelines:

### BOSH Pipeline

This pipeline runs unit and integration tests inside a docker container.

This pipeline has the following Tasks:

1. Run Unit Tests
    1. `export RUBY_VERSION=1.9.3`
    2. `export RUBY_VERSION=2.1.2`
    
    ```
    gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/unit/job.sh
    ```

2. Run Integration Tests
    1. `export RUBY_VERSION=1.9.3 && export DB=postgres`
    2. `export RUBY_VERSION=1.9.3 && export DB=mysql`
    3. `export RUBY_VERSION=2.1.2 && export DB=postgres`
    4. `export RUBY_VERSION=2.1.2 && export DB=mysql`
    
    ```
    gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/integration/job.sh
    ```

### Docker Pipeline

This pieline creates and uploads the docker image used by the bosh pipeline.

This pipeline has the following Tasks:

1. Build & upload docker image (push to Docker Hub requires login)
    
    ```
    gocd/docker/build/image/job.sh
    ```

### Exploring the docker container

To get into an interactive bash shell inside the container:
```
docker run -t -i -v $(pwd):/opt/bosh bosh/integration /bin/bash
```
