# bosh-stemcell

Tools for creating stemcells

## Bringing up stemcell building VM

### Once-off manual steps:

0. Upload a keypair called "bosh" to AWS that you'll use to connect to the remote vm later
0. Create "bosh-stemcell" security group on AWS to allow SSH access to the stemcell (once per AWS account)
0. Add instructions to set BOSH_AWS_... environment variables
0. Install the vagrant plugins we use:

        vagrant plugin install vagrant-berkshelf
        vagrant plugin install vagrant-omnibus
        vagrant plugin install vagrant-aws --plugin-version 0.5.0

### Bring up the vagrant stemcell building VM

From a fresh copy of the bosh repo:

    export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    cd bosh-stemcell
    vagrant up remote --provider=aws

## Updating source code on stemcell building VM

With existing stemcell building VM run:

    export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    cd bosh-stemcell
    vagrant provision remote


## Build an OS image

If you have changes that will require new OS image you need to build one. A stemcell with a custom OS image can be built using the stemcell-building VM created earlier.

    vagrant ssh -c '
      cd /bosh
      bundle exec rake stemcell:build_os_image[ubuntu,trusty,/tmp/ubuntu_base_image.tgz]
    ' remote

See below [Building the stemcell with local OS image](#building-the-stemcell-with-local-os-image) on how to build stemcell with the new OS image.

## Building a stemcell

### Building the stemcell with published OS image

Substitute *\<current_build\>* with the current build number, which can be found by looking at [bosh artifacts](http://bosh_artifacts.cfapps.io).
The final two arguments are the S3 bucket and key for the OS image to use, which can be found by reading the OS\_IMAGES document in this project.

    vagrant ssh -c '
      cd /bosh
      CANDIDATE_BUILD_NUMBER=<current_build> http_proxy=http://localhost:3142/ bundle exec rake stemcell:build[vsphere,esxi,centos,nil,go,bosh-os-images,bosh-centos-6_5-os-image.tgz]
    ' remote


### Building the stemcell with local OS image

    vagrant ssh -c '
      cd /bosh
      bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,go,/tmp/ubuntu_base_image.tgz]
    ' remote

### Building light stemcell

AWS stemcells can be shipped in light format which includes a reference to a public AMI. This speeds up the process of uploading the stemcell to AWS. To build a light stemcell:

    vagrant ssh -c '
      cd /bosh
      export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
      export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
      bundle exec rake stemcell:build_light[/tmp/bosh-stemcell.tgz,hvm]
    ' remote
