This directory contains the Docker image which will be used for compiling releases. We publish this to
Docker Hub at [`bosh/compiled-release`](https://hub.docker.com/r/bosh/compiled-release/)


# Development

Bring up the vagrant box and ssh in...

    host$ vagrant up
    host$ vagrant ssh

The `/opt/bosh` directory will point to bosh project directory on your host...

    vagrant$ cd /opt/bosh/ci/pipelines/compiled-releases/docker

To test if docker is installed and running...

    vagrant$ docker version

If docker daemon isn't running, try this:

    host$ vagrant destroy; vagrant box update; vagrant up

## Rebuilding the Container Image

Rebuild the container with the `build` script...

    vagrant$ ./build


## Testing bosh-init functionality

You can use `run` to start a container which has mounted your project to `/opt/bosh`...

    vagrant$ ./run
Check if bosh-init installed
    
    container$ bosh-init -v

Generate manifest using generate-bosh-init-manifest.sh script using your AWS credentials. Make sure that ssh_tunnel_key
contains valid key.
    

## Docker Hub

After building and testing a new container image, push it to Docker Hub with `push`...

    vagrant$ ./push
