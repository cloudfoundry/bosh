# bosh-stemcell

Tools for creating stemcells

## Choosing execution environment

Stemcells can be built using either a local Docker container or a Vagrant VM on AWS.

To run a given command in Docker:

    # run this command from the root of the bosh project
    docker run -it -v $PWD:/bosh -w /bosh -u ubuntu --privileged bosh/os-image-stemcell-builder

    # from within docker container
    bundle install --local
    <STEMCELL_COMMAND>

To run a command in Vagrant:

    vagrant ssh -c '
      cd /bosh
      bundle install --local
      <STEMCELL_COMMAND>
    ' remote

Jump to [Vagrant Setup](#vagrant-setup) for instructions on configuring the Vagrant box.

## Build an OS image

An OS image is a tarball that contains a snapshot of an entire OS filesystem that contains all the libraries and system utilities that the BOSH agent depends on. It does not contain the BOSH agent or the virtualization tools: there is [a separate Rake task](#building-the-stemcell-with-local-os-image) that adds the BOSH agent and a chosen set of virtualization tools to any base OS image, thereby producing a stemcell.

If you have changes that will require new OS image you need to build one. A stemcell with a custom OS image can be built using the stemcell-building VM described above.

    bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz]

The arguments to `stemcell:build_os_image` are:

1. *`operating_system_name`* identifies which type of OS to fetch. Determines which package repository and packaging tool will be used to download and assemble the files. Must match a value recognized by the  [OperatingSystem](lib/bosh/stemcell/operatingsystem.rb) module. Currently, `ubuntu` `centos` and `rhel` are recognized.
2. *`operating_system_version`* an identifier that the system may use to decide which release of the OS to download. Acceptable values depend on the operating system. For `ubuntu`, use `trusty`. For `centos` or `rhel`, use `7`.
3. *`os_image_path`* the path to write the finished OS image tarball to. If a file exists at this path already, it will be overwritten without warning.

### Special requirements for building a RHEL OS image

There are a few extra steps you need to do before building a RHEL OS image:

1. Start up or re-provision the stemcell building machine (run `vagrant up` or `vagrant provision` from this directory)
2. Download the [RHEL 7.0 Binary DVD](https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.0/x86_64/product-downloads) image and use `scp` to copy it to the stemcell building machine. Note that RHEL 7.1 does not yet build correctly.
3. On the stemcell building machine, mount the RHEL 7 DVD at `/mnt/rhel`:

        # mkdir -p /mnt/rhel
        # mount rhel-server-7.0-x86_64-dvd.iso /mnt/rhel

4. On the stemcell building machine, put your Red Hat Account username and password into environment variables:

        $ export RHN_USERNAME=my-rh-username@company.com
        $ export RHN_PASSWORD=my-password

5. On the stemcell building machine, run the stemcell building rake task:

        $ bundle exec rake stemcell:build_os_image[rhel,7,$PWD/tmp/rhel_7_base_image.tgz]

See below [Building the stemcell with local OS image](#building-the-stemcell-with-local-os-image) on how to build stemcell with the new OS image.

### Special requirements for building a PhotonOS image

There are a few extra steps you need to do before building a PhotonOS image:

1. Start up or re-provision the stemcell building machine (run `vagrant up` or `vagrant provision` from this directory)
2. Download the [latest PhotonOS ISO image](https://vmware.bintray.com/photon/iso/) and use `scp` to copy it to the stemcell building machine. The version must be TP2-dev or newer.
3. On the stemcell building machine, mount the PhotonOS ISO at `/mnt/photonos`:

        # mkdir -p /mnt/photonos
        # mount photon.iso /mnt/photonos

4. On the stemcell building machine, run the stemcell building rake task:

        $ bundle exec rake stemcell:build_os_image[photonos,TP2,$PWD/tmp/photon_TP2_base_image.tgz]

See below [Building the stemcell with local OS image](#building-the-stemcell-with-local-os-image) on how to build stemcell with the new OS image.

## Building a stemcell

### Building the stemcell with published OS image

Substitute *\<current_build\>* with the current build number, which can be found by looking at [bosh.io/stemcells](https://bosh.io/stemcells). Note that the last two arguments to the rake command are the S3 bucket and key of the OS image to use (i.e. in the example below, the .tgz will be downloaded from [http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz](http://bosh-os-images.s3.amazonaws.com/bosh-centos-7-os-image.tgz)). More info at OS\_IMAGES.

    CANDIDATE_BUILD_NUMBER=<current_build> bundle exec rake \
      stemcell:build[vsphere,esxi,centos,7,go,bosh-os-images,bosh-centos-7-os-image.tgz]

### Building the stemcell with local OS image

    bundle exec rake stemcell:build_with_local_os_image[aws,xen,ubuntu,trusty,go,$PWD/tmp/ubuntu_base_image.tgz]


Public OS images can be obtained here:

* latest Ubuntu - https://s3.amazonaws.com/bosh-os-images/bosh-ubuntu-trusty-os-image.tgz
* latest Centos - https://s3.amazonaws.com/bosh-os-images/bosh-centos-7-os-image.tgz

### Building light stemcell

**Warning:** You must use Vagrant on AWS to build light stemcells.

AWS stemcells can be shipped in light format which includes a reference to a public AMI. This speeds up the process of uploading the stemcell to AWS. To build a light stemcell:

    export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    bundle exec rake stemcell:build_light[$PWD/tmp/bosh-stemcell.tgz,hvm]

To build for specific region specify `BOSH_AWS_REGION` environment variable.

NOTE: to build a stemcell for the AWS HVM virtualization type, you must build a light stemcell.

### When things go sideways

If you find yourself debugging any of the above processes, here is what you need to know:

1. Most of the action happens in Bash scripts, which are referred to as _stages_, and can
   be found in `stemcell_builder/stages/<stage_name>/apply.sh`.
2. You should make all changes on your local machine, and sync them over to the AWS stemcell
   building machine using `vagrant provision remote` as explained earlier on this page.
3. While debugging a particular stage that is failing, you can resume the process from that
   stage by adding `resume_from=<stage_name>` to the end of your `bundle exec rake` command.
   When a stage's `apply.sh` fails, you should see a message of the form
   `Can't find stage '<stage>' to resume from. Aborting.` so you know which stage failed and
   where you can resume from after fixing the problem.

   For example:

   ```
   bundle exec rake stemcell:build_os_image[ubuntu,trusty,$PWD/tmp/ubuntu_base_image.tgz] resume_from=rsyslog_config
   ```

## <a name="vagrant-setup"></a>Vagrant Setup

**Warning:** You cannot building a stemcell using Vagrant on Virtualbox.

### Bring up the vagrant stemcell building VM

Note: Use US East (Northern Virginia) region when using AWS in following steps. AMI (Amazon Machine Image) to be used for the stemcell building VM is in the US East (Northern Virginia) region.

0. Upload a keypair called "bosh" to AWS that you'll use to connect to the remote vm later
0. Create "bosh-stemcell" security group on AWS to allow SSH access to the stemcell (once per AWS account)
0. Install the vagrant plugins we use:

        vagrant plugin install vagrant-aws


From a fresh copy of the bosh repo:

    git submodule update --init --recursive

If you use AWS VPC environment, run:

    export BOSH_VAGRANT_KEY_PATH=PATH-TO-YOUR-SSH-KEY
    export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    export BOSH_AWS_SECURITY_GROUP=YOUR-AWS-SECURITY-GROUP-ID
    export BOSH_AWS_SUBNET_ID=YOUR-AWS-SUBNET-ID
    cd bosh-stemcell
    vagrant up remote --provider=aws

(Note: BOSH\_AWS\_SECURITY\_GROUP should be security group id (e.g. "sg-b799b9dc"), instead of name "bosh-stemcell")

### Updating source code on stemcell building VM

With existing stemcell building VM run:

    export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    cd bosh-stemcell
    vagrant provision remote

### Configure your local ssh and scp to communicate with the stemcell building VM

Once the stemcell-building machine is up, run:

    vagrant ssh-config remote

Then copy the resulting output into your `~/.ssh/config` file.

Once this has been done, you can ssh into the stemcell building machine with `ssh remote`
and you can copy files to and from it using `scp localfile remote:/path/to/destination`
