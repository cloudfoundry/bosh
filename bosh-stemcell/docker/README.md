This directory contains the Docker image which will be used for building OS Images and Stemcells. We publish this to
Docker Hub at [`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/)


# Development

Bring up the vagrant box and ssh in...

    host$ vagrant up
    host$ vagrant ssh

The `/opt/bosh` directory will point to bosh project directory on your host...

    vagrant$ cd /opt/bosh/bosh-stemcell/docker

To test if docker is installed and running...

    vagrant$ docker version

If docker daemon isn't running, try this:

    host$ vagrant destroy; vagrant box update; vagrant up

## Rebuilding the Container Image

First download the ovftool installer from VMWare. Details about this can be found at
[my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489).
Specifically...

 1. Download the `*.bundle` file to this directory (`bosh-stemcell/docker`)
 2. When upgrading versions, update `Dockerfile` with the new file path and SHA

Rebuild the container with the `build` script...

    vagrant$ ./build

## Building and Testing OS Images and Stemcells

See [bosh-stemcell README.md](../README.md).

## Docker Hub

After building and testing a new container image, push it to Docker Hub with `push`...

    vagrant$ ./push
