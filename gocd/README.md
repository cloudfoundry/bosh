# BOSH GoCD Continuous Integration

This module is a set of scripts to run the BOSH unit and integration tests in linux containers. It's primarily meant to be run with GoCD, but can also be run locally on linux machines or inside a linux VM.


## Usage: GoCD Continuous Integration

The Pivotal BOSH team uses Docker containers for continuous integration of the BOSH project ["develop" branch](https://github.com/cloudfoundry/bosh/tree/develop) run on [GoCD](http://www.go.cd/).

### GoCD BOSH Pipeline

This pipeline runs the unit and integration tests for BOSH inside a Docker container. It performs the following tasks:

1. Run Unit Tests

    ```
    $ export RUBY_VERSION=1.9.3                         # Pipeline Job no. 1
    $ export RUBY_VERSION=2.1.2                         # Pipeline Job no. 2

    # For each job...
    $ gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/unit/job.sh
    ```

2. Run Integration Tests

    ```
    $ export RUBY_VERSION=1.9.3 && export DB=postgres   # Pipeline Job no. 1
    $ export RUBY_VERSION=1.9.3 && export DB=mysql      # Pipeline Job no. 2
    $ export RUBY_VERSION=2.1.2 && export DB=postgres   # Pipeline Job no. 3
    $ export RUBY_VERSION=2.1.2 && export DB=mysql      # Pipeline Job no. 4

    # For each job...
    $ gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/integration/job.sh
    ```

### GoCD Docker Container Pipeline

This pipeline builds and publishes the Docker image used by the BOSH pipeline, using the following steps:

    ```
    # The GoCD pipeline-built containers are published and consumed from
    # a private Docker registry.

    $ export DOCKER_IMAGE="docker.gocd.cf-app.com:5000/bosh-container"
    $ gocd/docker/build/image/job.sh
    ```


## Usage: Running Tests in Development

To run tests locally, follow these steps.

1. (If running in VM) Bring up the VM
    
    ```
    # If behind a proxy...

    # 1. Set http_proxy, https_proxy and no_proxy first
    $ export http_proxy=http://user:pwd@myproxy.example.com:8080
    $ export https_proxy=http://user:pwd@myproxy.example.com:8080
    $ export no_proxy=localhost
    $ cd gocd/docker
    $ vagrant up --provider virtualbox

    # 2. Reload to propagate settings to docker in VM
    $ vagrant reload
    ```

2. (If running in VM) SSH into the VM
    
    ```
    $ vagrant ssh
    ```

3. Pull the docker container from Docker Hub
    
    ```
    $ docker pull bosh/integration
    ```

4. Copy the mounted bosh dir (so that it can chown and write to it)
    ```
    $ sudo cp -r /opt/bosh /opt/bosh-copy
    $ cd /opt/bosh-copy
    ```

5. Select which version of ruby to use
    1. `$ export RUBY_VERSION=2.1.2`
    2. `$ export RUBY_VERSION=1.9.3`

6. (Optional) Select which database to use
    1. `$ export DB=postgres` (default)
    2. `$ export DB=mysql`

4. Run the unit tests in the docker container (downloads the docker image if not built/cached locally)
    
    ```
    $ gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/unit/job.sh
    ```

5. Run the integration tests in the docker container (downloads the docker image if not built/cached locally)
    
    ```
    $ gocd/bosh/run-in-container.sh /opt/bosh/gocd/bosh/tests/integration/job.sh
    ```

6. (If running in VM) Destroy the VM
    
    ```
    $ vagrant destroy bosh-docker-builder --force
    ```


## Usage: Running an Interactive `bash` Shell within the Container

Follow the steps above for "Running Tests...", then:

```
$ docker run -t -i -v $(pwd):/opt/bosh bosh/integration /bin/bash
```


## Publishing a New Docker Container

To publish a new container to the public registry at Docker Hub:

1. Build the container image through the GoCD pipeline as described above
2. Pull the newly built image from the private registry:

    ```
    $ docker pull docker.gocd.cf-app.com:5000/bosh-container
    ```

3. Tag the image to prepare for pushing to the Docker Hub:

    ```
    $ docker list
      # output will be something like...
      # REPOSITORY                                  TAG     IMAGE ID      ...
      # bosh/integration                            latest  <PUBLIC_ID>   ...
      # docker.gocd.cf-app.com:5000/bosh-container  latest  <PRIVATE_ID>  ...
    $ docker tag -f <PRIVATE_ID> bosh/integration
    ```

4. Push the image to the public Docker Hub registry:

    ```
    $ docker push bosh/integration
    ```
