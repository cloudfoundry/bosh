# bosh-stemcell

Tools for creating stemcells

## Building a stemcell

#### Once-off manual steps:

0. Upload a keypair called "bosh" to AWS that you'll use to connect to the remote vm later
0. Create "bosh-stemcell" security group on AWS to allow SSH access to the stemcell (once per AWS account)
0. Add instructions to set BOSH_AWS_... environment variables
0. Install the vagrant plugins we use:

        vagrant plugin install vagrant-berkshelf
        vagrant plugin install vagrant-omnibus
        vagrant plugin install vagrant-aws       --plugin-version 0.3.0

#### Bring up the vagrant stemcell building VM

From a fresh copy of the bosh repo:

    export BOSH_AWS_ACCESS_KEY_ID=YOUR-AWS-ACCESS-KEY
    export BOSH_AWS_SECRET_ACCESS_KEY=YOUR-AWS-SECRET-KEY
    cd bosh-stemcell
    vagrant up remote --provider=aws

#### Build the stemcell from inside the VM

Substitute *\<current_build\>* with the current build number, which can be found by looking at [bosh artifacts](http://bosh_artifacts.cfapps.io).
The final two arguments are the S3 bucket and key for the OS image to use, which can be found by reading the OS\_IMAGES document in this project.

    vagrant ssh -c '
      cd /bosh
      CANDIDATE_BUILD_NUMBER=<current_build> http_proxy=http://localhost:3142/ bundle exec rake stemcell:build[vsphere,centos,nil,ruby,bosh-os-images,bosh-centos-6_5-os-image.tgz]
    ' remote

# Run the stemcell locally with Fusion

VMware Fusion is the preferred local virtual environment.  You can [purchase it here](http://www.vmware.com/products/fusion/).  Once you have Fusion installed:

* Unpack the stemcell tarball.
* Rename the new `image` file to `image.tgz` and untar that as well.  You should now have an `image.ovf` file.
* Start VMware Fusion and import this file (**File** -> **Import**)
* Save the imported OVF as `image.vmwarevm` in the `tmp` folder.
* You should see a new VM in your VM library.
* Double click that new VM and it should be booted.

## Add the NIC

Before starting the VM in VirtualBox:

1. Add a network interface (**Virtual Machine** > **Settings** > **Add Device...** > **Network Adapter**)
1. Select NAT networking (the default)

# Run the stemcell locally with VirtualBox

## Import the VM

- The stemcell is dropped into `bosh/tmp/bosh-stemcell-???-vsphere-esxi-centos.tgz`.
- Untar that file.  You now have a file named `image`.
- Rename that to `image.tgz`, and untar *that* file.  You now have a file named `image.ovf`.
- Double click on that file to open it in VirtualBox.

## Add the NIC

Before starting the VM in VirtualBox:

1. Add a network interface (**Settings** > **Network** > **Adapter 1** > **Enable**)
1. Select NAT networking (the default)
1. Click on advanced
1. Click on Port Forwarding and enable the following rule:
    * Name: SSH
    * Protocol: TCP
    * Host IP: 127.0.0.1
    * Host Port: 3333
    * Guest IP: blank
    * Guest Port: 22

# Boot the VM

Save the configuration and boot the VM.  Once you're booted, login as `root`/`c1oudc0w`.

## Configure network locally

### Fusion

```bash
$ grep subnet /Library/Preferences/VMware\ Fusion/*/dhcpd.conf
/Library/Preferences/VMware Fusion/vmnet1/dhcpd.conf:subnet 172.16.0.0 netmask 255.255.255.0 {
/Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf:subnet 172.16.210.0 netmask 255.255.255.0 {
```

```bash
ifconfig eth0 172.16.210.30/24 up
route add default gw 172.16.210.2 eth0
```

### VirtualBox

You'll want to pick an IP that's not in use by your stemcell building vm. 10.0.2.30 *should* be fine.

```bash
ifconfig eth0 10.0.2.30/24 up
route add default gw 10.0.2.2 eth0
```

Test the network with `ping 8.8.8.8`

# Build an OS image

A stemcell with a custom OS image can be built using the stemcell-building VM created earlier.

    vagrant ssh -c '
      cd /bosh
      bundle exec rake stemcell:build_os_image[ubuntu,lucid,/tmp/ubuntu_base_image.tgz]
      bundle exec rake stemcell:build_with_local_os_image[aws,ubuntu,lucid,ruby,/tmp/ubuntu_base_image.tgz]
    ' remote

