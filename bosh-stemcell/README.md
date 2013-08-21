# bosh-stemcell

Tools to create stemcells

## Install the vagrant plugins we use:

```
vagrant plugin install vagrant-berkshelf --plugin-version 1.3.3
vagrant plugin install vagrant-omnibus   --plugin-version 1.1.0
````

## Smoke test

```
vagrant up
vagrant ssh -c 'cd /bosh; bundle; bundle exec rake -T stemcell' # If this works you're set.
```
