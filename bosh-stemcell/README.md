# bosh-stemcell

Tools for creating stemcells.


## Setup

Historically stemcells have been built using an AWS instance created by vagrant. We're in the process of switching that process to use containers. Unless you have a reason for building with vagrant, please use the Container-based method and report any issues.

First make sure you have a local copy of this repository. If you already have a stemcell-building environment set up and ready, skip to the **Build Steps** section. Otherwise, follow one of these two methods before trying to run the commands in **Build Steps**.


### Container-based

The Docker-based environment files are located in `ci/docker/os-image-stemcell-builder`...

    host$ cd ci/docker/os-image-stemcell-builder

If you do not already have Docker running, use `vagrant` to start a new VM which has Docker, and then change back into the `./docker` directory...

    host$ vagrant up
    host$ vagrant ssh

Once you have Docker running, run `./run`...

    vagrant$ /opt/bosh/ci/docker/run os-image-stemcell-builder
    container$ whoami
    ubuntu

*You're now ready to continue from the **Build Steps** section.*

**Troubleshooting**: if you run into issues, try destroying any existing VM, update your box, and try again...

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


### AWS-based

The AWS_based environment files are located in this directory. The `Vagrantfile` refers to an image in `us-east-1` (*no other region can be used to build images*) and has a few other requirements...

0. Upload a keypair called `bosh` to AWS that you'll use to connect to the remote vm later
0. Create `bosh-stemcell` security group on AWS to allow SSH access to the stemcell (once per AWS account)
0. Install the vagrant plugins we use:

        host$ vagrant plugin install vagrant-aws

0. Export your AWS security credentials:

        host$ export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
        host$ export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY

0. If you use AWS VPC you must also set some additional environment variables:

        host$ export BOSH_VAGRANT_KEY_PATH=PATH-TO-YOUR-BOSH-SSH-KEY
        host$ export BOSH_AWS_SECURITY_GROUP=YOUR-AWS-SECURITY-GROUP-ID # specify ID (e.g. sg-a1b2c3d4) not the name
        host$ export BOSH_AWS_SUBNET_ID=YOUR-AWS-SUBNET-ID

Once you have prepared your environment and configuration, run `vagrant up`...

    host$ cd bosh-stemcell
    host$ vagrant up remote --provider=aws

You can then use `vagrant ssh` to connect...

    host$ vagrant ssh remote

*You're now ready to continue from the **Build Steps** section.*

Whenever you make changes to your local `bosh` directory, you'll need to manually sync them to your existing VM...

    host$ cd bosh-stemcell
    host$ vagrant provision remote

Once the stemcell-building machine is up, you can run:

    host$ vagrant ssh-config remote

Then copy the resulting output into your `~/.ssh/config` file.

Once this has been done, you can ssh into the stemcell building machine with `ssh remote`
and you can copy files to and from it using `scp localfile remote:/path/to/destination`


## Build Steps

At this point, you should be ssh'd and running within your container or AWS instance in the `bosh` directory. Start by installing the latest dependencies before continuing to a specific build task...

    $ echo $PWD
    /opt/bosh (unless you are running on an AWS instance, then it is /bosh)
    $ bundle install --local


### Build an OS image

An OS image is a tarball that contains a snapshot of an entire OS filesystem that contains all the libraries and system utilities that the BOSH agent depends on. It does not contain the BOSH agent or the virtualization tools: there is [a separate Rake task](#building-the-stemcell-with-local-os-image) that adds the BOSH agent and a chosen set of virtualization tools to any base OS image, thereby producing a stemcell.

The OS Image should be rebuilt when you are making changes to which packages we install in the operating system, or when making changes to how we configure those packages, or if you need to pull in and test an updated package from upstream.

    $ mkdir -p $PWD/tmp
    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]

The arguments to `stemcell:build_os_image` are:

0. *`operating_system_name`* identifies which type of OS to fetch. Determines which package repository and packaging tool will be used to download and assemble the files. Must match a value recognized by the  [OperatingSystem](lib/bosh/stemcell/operatingsystem.rb) module. Currently, `ubuntu` `centos` and `rhel` are recognized.
0. *`operating_system_version`* an identifier that the system may use to decide which release of the OS to download. Acceptable values depend on the operating system. For `ubuntu`, use `trusty`. For `centos` or `rhel`, use `7`.
0. *`os_image_path`* the path to write the finished OS image tarball to. If a file exists at this path already, it will be overwritten without warning.


#### Special requirements for building a RHEL OS image

There are a few extra steps you need to do before building a RHEL OS image:

0. Start up or re-provision the stemcell building machine (run `vagrant up` or `vagrant provision` from this directory)
0. Download the [RHEL 7.0 Binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.0/x86_64/product-downloads) image and use `scp` to copy it to the stemcell building machine. Note that RHEL 7.1 does not yet build correctly.
0. On the stemcell building machine, mount the RHEL 7 DVD at `/mnt/rhel`:

        $ mkdir -p /mnt/rhel
        $ mount rhel-server-7.0-x86_64-dvd.iso /mnt/rhel

0. On the stemcell building machine, put your Red Hat Account username and password into environment variables:

        $ export RHN_USERNAME=my-rh-username@company.com
        $ export RHN_PASSWORD=my-password

0. On the stemcell building machine, run the stemcell building rake task:

        $ bundle exec rake stemcell:build_os_image[rhel,7,$PWD/tmp/rhel_7_base_image.tgz]

See below [Building the stemcell with local OS image](#building-the-stemcell-with-local-os-image) on how to build stemcell with the new OS image.


#### Special requirements for building a PhotonOS image

There are a few extra steps you need to do before building a PhotonOS image:

0. Start up or re-provision the stemcell building machine (run `vagrant up` or `vagrant provision` from this directory)
0. Download the [latest PhotonOS ISO image](https://vmware.bintray.com/photon/iso/) and use `scp` to copy it to the stemcell building machine. The version must be TP2-dev or newer.
0. On the stemcell building machine, mount the PhotonOS ISO at `/mnt/photonos`:

        $ mkdir -p /mnt/photonos
        $ mount photon.iso /mnt/photonos

0. On the stemcell building machine, run the stemcell building rake task:

        $ bundle exec rake stemcell:build_os_image[photonos,TP2,$PWD/tmp/photon_TP2_base_image.tgz]

See below [Building the stemcell with local OS image](#building-the-stemcell-with-local-os-image) on how to build stemcell with the new OS image.


### Building a stemcell

The stemcell should be rebuilt when you are making and testing BOSH-specific changes on top of the base-OS Image such as new bosh-agent versions, or updating security configuration, or changing user settings.

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


#### Building light stemcell

**Warning:** You must use Vagrant on AWS to build light stemcells for AWS.

AWS stemcells can be shipped in light format which includes a reference to a public AMI. This speeds up the process of uploading the stemcell to AWS. To build a light stemcell:

    $ export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    $ export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    $ bundle exec rake stemcell:build_light[$PWD/tmp/bosh-stemcell.tgz,hvm]

To build for specific region specify `BOSH_AWS_REGION` environment variable.

NOTE: to build a stemcell for the AWS HVM virtualization type, you must build a light stemcell.


### Troubleshooting

If you find yourself debugging any of the above processes, here is what you need to know:

0. Most of the action happens in Bash scripts, which are referred to as _stages_, and can
   be found in `stemcell_builder/stages/<stage_name>/apply.sh`.
0. You should make all changes on your local machine, and sync them over to the AWS stemcell
   building machine using `vagrant provision remote` as explained earlier on this page.
0. While debugging a particular stage that is failing, you can resume the process from that
   stage by adding `resume_from=<stage_name>` to the end of your `bundle exec rake` command.
   When a stage's `apply.sh` fails, you should see a message of the form
   `Can't find stage '<stage>' to resume from. Aborting.` so you know which stage failed and
   where you can resume from after fixing the problem.

For example:

    $ bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config

#### How to run tests for OS Images
The OS tests are meant to be run agains the OS environment to which they belong. When you run the `stemcell:build_os_image` rake task, it will create a .raw OS image that it runs the OS specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests. 

##### Docker

To run the `centos_7_spec.rb` tests for example you will need to: 

* `bundle exec rake stemcell:build_os_image[centos,7,$PWD/tmp/centos_base_image.tgz]`
* -make changes-

Then run the following:

    cd /opt/bosh/bosh-stemcell; OS_IMAGE=/opt/bosh/tmp/centos_base_image.tgz bundle exec rspec -fd spec/os_image/centos_7_spec.rb

##### AWS

In case you are running these on an AWS environment, you will need to: 
* `bundle exec rake stemcell:build_os_image[centos,7,$PWD/tmp/centos_base_image.tgz]`
* -make changes-
* `vagrant rsync` in your local machine

Then run the following:

    export STEMCELL_IMAGE=/mnt/stemcells/aws/xen/centos/work/work/aws-xen-centos.raw
    export STEMCELL_WORKDIR=/mnt/stemcells/aws/xen/centos/work/work
    export OS_NAME=centos
    cd bosh-stemcell/
    bundle exec rspec -fd --tag ~exclude_on_aws spec/os_image/centos_7_spec.rb
    
#### How to run tests for Stemcell
When you run the `stemcell:build_with_local_os_image` or `stemcell:build` rake task, it will create a stemcell that it runs the stemcell specific tests against. You will need to run the rake task the first time you create your docker container, but everytime after, as long as you do not destroy the container, you should be able to just run the specific tests. 

##### Docker

To run the stemcell tests when building against local OS image you will need to: 

* `bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,go,$PWD/tmp/ubuntu_base_image.tgz]`
* -make test changes-

Then run the following:
```sh
    $ cd /opt/bosh/bosh-stemcell; \ 
    STEMCELL_IMAGE=/mnt/stemcells/aws/xen/ubuntu/work/work/aws-xen-ubuntu.raw \ 
    STEMCELL_WORKDIR=/mnt/stemcells/aws/xen/ubuntu/work/work/chroot \ 
    OS_NAME=ubuntu \ 
    bundle exec rspec -fd --tag ~exclude_on_aws \ 
    spec/os_image/ubuntu_trusty_spec.rb \ 
    spec/stemcells/ubuntu_trusty_spec.rb \ 
    spec/stemcells/go_agent_spec.rb \ 
    spec/stemcells/aws_spec.rb \ 
    spec/stemcells/stig_spec.rb \ 
    spec/stemcells/cis_spec.rb
```
    
#### Pro Tips

* If the OS image has been built and so long as you only make test case modifications you can just rerun the tests (without rebuilding OS image). Details in section `How to run tests for OS Images`

* If the Stemcell has been built and so long as you only make test case modifications you can rerun the tests (without rebuilding Stemcell. Details in section `How to run tests for Stemcell`

* It's possible to verify OS/Stemcell changes without making adeployment using the stemcell. For an AWS specific ubuntu stemcell, the filesytem is available at `/mnt/stemcells/aws/xen/ubuntu/work/work/chroot`
