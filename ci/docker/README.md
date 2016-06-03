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

# Building docker images

The docker images use a layered approach collecting common dependencies in a shared base. To build an image look at the
Dockerfile for the dependencies and use the `./build` script with the name of the directory containing the Dockerfile
to build the desired image. For example:

    vagrant$ ./build main-ruby-go
    vagrant$ ./build main

# Running the container

You can use `run` to start a container which has mounted your project to `/opt/bosh`...

    vagrant$ ./run main


For detailed stemcell building instructions, see the [stemcell readme](~/workspace/bosh/bosh-stemcell/README.md).
