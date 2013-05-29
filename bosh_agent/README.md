# Bosh agent

## Configuration

`bosh_agent` can be run in two configuration modes - infrastructure registry or CLI option overrides.

### Infrastructure registry configuration

`bosh_agent -c` attempts to load the config settings based on the infrastructure

For each different agent infrastructure:

* `bosh_agent -c -I aws` => attempts to load the config settings from an AWS registry; the registry HTTP address is provided to the bosh_agent via the [AWS user-data](https://github.com/cloudfoundry/bosh/blob/master/bosh_aws_cpi/lib/cloud/aws/instance_manager.rb#L159-L166)
* `bosh_agent -c -I vsphere` => attempts to load the config settings via a mounted fake cdrom
* `bosh_agent -c -I openstack`  => attempts to load the config settings from OpenStack registry (same as AWS registry - bosh_registry project folder); openstack user-data is provided by both user-data and a user-data.json file (the former isn't supported by Rackspace)

If the settings cannot be found as above, then it looks for a file `/var/vcap/bosh/settings.json` and loads that.

### CLI option overrides

Alternately, you can run `bosh_agent` without loading settings (without the `-c` flag).

* `bosh_agent` => uses the purely [default settings](https://github.com/cloudfoundry/bosh/blob/master/bosh_agent/bosh_agent#L9-22) from bosh_agent (defaults to NATS for communication & vsphere platform)
* `bosh_agent -n https://vcap:vcap@0.0.0.0:6868` => overrides default settings to tell `bosh_agent` to use https (as used by "bosh micro deploy" and mcf)

Run `bosh_agent --help` to see all the CLI option overrides.