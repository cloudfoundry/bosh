This directory contains the Docker image which will be used for building OS Images and Stemcells. We publish this to
Docker Hub at [`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/)


# Development

Bring up the vagrant box and ssh in...

    host$ vagrant up
    host$ vagrant ssh

The `/opt/bosh` directory will point to bosh project directory on your host...

    vagrant$ cd /opt/bosh/bosh-stemcell/docker


## Rebuilding the Container Image

First download the ovftool installer from VMWare. Details about this can be found at
[my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489).
Specifically...

 1. Download the `*.bundle` file to this directory (`bosh-stemcell/docker`)
 2. When upgrading versions, update `Dockerfile` with the new file path and SHA

Rebuild the container with the `build` script...

    vagrant$ ./build

After building and testing, push a new image to Docker Hub with `push`...

    vagrant$ ./push


## Testing OS Image changes

You can use `run` to start a container which has mounted your project to `/opt/bosh`...

    vagrant$ ./run
    container$ cd /opt/bosh
    container$ bundle install --local
    container$ bundle exec rake stemcell:build_os_image[ubuntu,trusty,/tmp/os-image.tgz]
