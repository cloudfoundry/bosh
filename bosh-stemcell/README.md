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
bundle install --local
sudo CANDIDATE_BUILD_NUMBER=961 bundle exec rake ci:build_stemcell[vsphere,ubuntu]
# ...or...
sudo CANDIDATE_BUILD_NUMBER=961 bundle exec rake ci:build_stemcell[vsphere,centos]
```
One trick to speed up stemcell building iteration is to leverage apt-cacher-ng
```
sudo bundle exec rake ci:build_stemcell[vsphere,centos] CANDIDATE_BUILD_NUMBER=961 http_proxy=http://localhost:3142
```

# Booting a vSphere stemcell with Fusion
## Given that you have VMware Fusion installed
When you want to boot and run a vSphere stemcell
* Download the stemcell tarball (provided by the pair working on the stemcell story)
* And you double-click the tgz file in Finder, it'll create a new folder
* In the new folder: Ctrl-Click the file "image", under "Open With", choose "Archive Utility"
* And then you'll have one more folder! There you find the file: image.ovf.
* Start VMware Fusion
* And you click File -> Import ... to import the above OVF file. You should see a new VM in your VM library.
* Double click that new VM and it should be booted.
