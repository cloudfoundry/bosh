# Running docker development environment

To build and run the docker images use Vagrant:

Required vagrant version is 1.7.4.

Bring up the vagrant box and ssh in...

    host$ vagrant up
    host$ vagrant ssh

The `/opt/bosh` directory will point to bosh project directory on your host...

    vagrant$ cd /opt/bosh/ci/docker

To test if docker is installed and running...

    vagrant$ docker version

If your VM is having trouble, try destroying it and ensuring you are using a recent box before starting it again...

    host$ vagrant destroy
    host$ vagrant box update

#### Development

The Docker image is published to [`bosh/os-image-stemcell-builder`](https://hub.docker.com/r/bosh/os-image-stemcell-builder/).

If you need to rebuild the image, first download the ovftool installer from VMWare. Details about this can be found at [my.vmware.com](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=489). Specifically...

0. Download the `*.bundle` file to the docker image directory (`ci/docker/os-image-stemcell-builder`)
0. When upgrading versions, update `Dockerfile` with the new file path and SHA

Rebuild the container with the `build` script...

    vagrant$ ./build os-image-stemcell-builder

When ready, `push` to DockerHub and use the credentials from LastPass...

    vagrant$ cd os-image-stemcell-builder
    vagrant$ ./push
    
# Building docker images

The docker images use a layered approach collecting common dependencies in a shared base. To build an image look at the
Dockerfile for the dependencies and use the `./build` script with the name of the directory containing the Dockerfile
to build the desired image. For example:

    vagrant$ ./build main-ruby-go
    vagrant$ ./build main

# Running the container

You can use `run` to start a container which has mounted your project to `/opt/bosh`...

    vagrant$ ./run main

### Build an OS image

An OS image is a tarball that contains a snapshot of an entire OS filesystem that contains all the libraries and system utilities that the BOSH agent depends on. It does not contain the BOSH agent or the virtualization tools: there is [a separate Rake task](#building-the-stemcell-with-local-os-image) that adds the BOSH agent and a chosen set of virtualization tools to any base OS image, thereby producing a stemcell.

The OS Image should be rebuilt when you are making changes to which packages we install in the operating system, or when making changes to how we configure those packages, or if you need to pull in and test an updated package from upstream.

    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]

The arguments to `stemcell:build_os_image` are:

0. *`operating_system_name`* identifies which type of OS to fetch. Determines which package repository and packaging tool will be used to download and assemble the files. Must match a value recognized by the  [OperatingSystem](lib/bosh/stemcell/operatingsystem.rb) module. Currently, `ubuntu` `centos` and `rhel` are recognized.
0. *`operating_system_version`* an identifier that the system may use to decide which release of the OS to download. Acceptable values depend on the operating system. For `ubuntu`, use `trusty`. For `centos` or `rhel`, use `7`.
0. *`os_image_path`* the path to write the finished OS image tarball to. If a file exists at this path already, it will be overwritten without warning.

### Building a stemcell

The stemcell should be rebuilt when you are making and testing BOSH-specific changes on top of the base-OS Image such as new bosh-agent versions, or updating security configuration, or changing user settings.

*Note:* to speed stemcell building during development, disable the old, bosh-micro-building steps before running `bundle` to avoid the time required to compile the bosh release...

    $ export BOSH_MICRO_ENABLED=no


#### with published OS image

The last two arguments to the rake command are the S3 bucket and key of the OS image to use (i.e. in the example below, the .tgz will be downloaded from [http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz](http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz)). More info at OS\_IMAGES.

    $ bundle exec rake stemcell:build[aws,xen,ubuntu,trusty,go,bosh-os-images,bosh-ubuntu-trusty-os-image.tgz]

By default, the stemcell build number will be `0000`. If you need to manually configure it, first run...

    $ export CANDIDATE_BUILD_NUMBER=<current_build>


#### with local OS image

If you want to use an OS Image that you just created, use the `stemcell:build_with_local_os_image` task, specifying the OS image tarball.

    $ bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,go,$PWD/tmp/ubuntu_base_image.tgz]

You can also download OS Images from the public S3 bucket. Public OS images can be obtained here:

* latest Ubuntu - https://s3.amazonaws.com/bosh-os-images/bosh-ubuntu-trusty-os-image.tgz
* latest CentOS - https://s3.amazonaws.com/bosh-os-images/bosh-centos-7-os-image.tgz

*Note*: you may need to append `?versionId=value` to those tarballs. You can find the expected `versionId` by looking at [`os_image_versions.json`](./os_image_versions.json).

