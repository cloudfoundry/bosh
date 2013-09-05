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
