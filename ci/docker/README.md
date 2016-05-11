# Building docker image

The docker image is based on a shared image `main-ruby-go` which includes the base OS plus the Ruby and Go language
environment. The `main` image adds the parts needed for running the tests.

To build and run the docker images use Vagrant:

Required vagrant version is 1.7.4.

```
host$ vagrant up
host$ vagrant ssh
vagrant$ cd /opt/bosh/ci/docker
vagrant$ ./build.sh main-ruby-go
vagrant$ ./build.sh main
```
