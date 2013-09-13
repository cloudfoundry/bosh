# bosh-stemcell

Tools for creating stemcells

## Install the vagrant plugins we use:

```bash
vagrant plugin install vagrant-berkshelf --plugin-version 1.3.3
vagrant plugin install vagrant-omnibus   --plugin-version 1.1.0
```

## Building a vSphere stemcell

### Bring up the vagrant stemcell building VM

From a fresh copy of the bosh repo:

```bash
cd bosh-stemcell
vagrant up
vagrant ssh
```

You're now inside the vagrant VM.

### Install VMWare's ovftool

After logging into the vagrant VM

Download the ovftool from http://www.vmware.com/support/developer/ovf/ to `/bosh/tmp/ovftool.txt`

```bash
cd /bosh
curl $OVF_TOOL_URL > tmp/ovftool.txt
sudo bash tmp/ovftool.txt            # follow installation instructions
which ovftool                        # should return a location
```

# Build the stemcell

```
cd /bosh
bundle install --local
sudo bundle exec rake ci:build_stemcell[vsphere,centos] CANDIDATE_BUILD_NUMBER=980 http_proxy=http://localhost:3142
```

Alternatively, you can run that command without the caching proxy, and/or for another OS:

```
sudo CANDIDATE_BUILD_NUMBER=980 bundle exec rake ci:build_stemcell[vsphere,ubuntu]
```

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

# Run the stemcell locally with VirtualBox

## Import the VM

The stemcell is dropped into `bosh/tmp/bosh-stemcell-???-vsphere-esxi-centos.tgz`.  Untar that file.  You now have a file named `image`.  Rename that to `image.tgz`, and untar *that* file.  You now have a file named `image.ovf`.  double click on that file to open it in VirtualBox.

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

You'll want to pick an IP that's not in use by your stemcell building vm (10.0.2.30 *should* be fine).

```
ifconfig eth0 10.0.2.30/24 up
route add default gw 10.0.2.2 eth0
```

Test the network with `ping 8.8.8.8`

