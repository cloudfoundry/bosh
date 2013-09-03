# bosh-stemcell

Tools for creating stemcells

## Install the vagrant plugins we use:

```bash
vagrant plugin install vagrant-berkshelf --plugin-version 1.3.3
vagrant plugin install vagrant-omnibus   --plugin-version 1.1.0
```

## Smoke test

```bash
vagrant up
vagrant ssh -c 'cd /bosh; bundle; bundle exec rake -T stemcell' # If this works you're set.
```

## Building a vSphere stemcell

### Bring up the vagrant stemcell building VM

From a fresh copy of the bosh repo

```bash
cd bosh-stemcell
vagrant up
```

### Install VMWare's `ovftool`

After loggint into the vagrant VM

```bash
vagrant ssh # login to the vagrant VM
# Download the ovftool from http://www.vmware.com/support/developer/ovf/ to <BOSH_REPO_LOCATION>/tmp/ovftool.txt
sudo bash /bosh/tmp/ovftool.txt # follow installation instructions
which ovftool # should return a location

# Build the stemcell
cd /bosh
bundle install --local
sudo CANDIDATE_BUILD_NUMBER=919 bundle exec rake ci:publish_stemcell[vsphere,ubuntu]
```