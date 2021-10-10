# BOSH

Cloud Foundry BOSH is an open source tool for release engineering, deployment, lifecycle management, and monitoring of distributed systems.

* Documentation:
	- [bosh.io/docs](https://bosh.io/docs) for installation & usage guide
	- [docs/ directory](docs/) for developer docs

* Slack: #bosh on <https://slack.cloudfoundry.org>

* Mailing lists:
    - [cf-bosh](https://lists.cloudfoundry.org/pipermail/cf-bosh) for asking BOSH usage and development questions
    - [cf-dev](https://lists.cloudfoundry.org/pipermail/cf-dev) for asking Cloud Foundry questions

* Related repos:
	- [Documentation source (docs-bosh)](https://github.com/cloudfoundry/docs-bosh)
	- [CLI v2 (bosh-cli)](https://github.com/cloudfoundry/bosh-cli)
	- [bosh-deployment](https://github.com/cloudfoundry/bosh-deployment) Canonical tested repo of dependencies and opsfiles used to deploy bosh
	- Stemcells: [bosh-linux-stemcell-builder](https://github.com/cloudfoundry/bosh-linux-stemcell-builder), [bosh-windows-stemcell-builder](https://github.com/cloudfoundry-incubator/bosh-windows-stemcell-builder), [aws-light-stemcell-builder](https://github.com/cloudfoundry-incubator/aws-light-stemcell-builder)
	- CPIs: [AWS](https://github.com/cloudfoundry-incubator/bosh-aws-cpi-release), [Azure](https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release), [Google](https://github.com/cloudfoundry-incubator/bosh-google-cpi-release), [OpenStack](https://github.com/cloudfoundry-incubator/bosh-openstack-cpi-release), [RackHD](https://github.com/cloudfoundry-incubator/bosh-rackhd-cpi-release), [SoftLayer](https://github.com/cloudfoundry-incubator/bosh-softlayer-cpi-release), [vSphere](https://github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release), [vCloud](https://github.com/cloudfoundry-incubator/bosh-vcloud-cpi-release), [VirtualBox](https://github.com/cppforlife/bosh-virtualbox-cpi-release), [Warden](https://github.com/cppforlife/bosh-warden-cpi-release)
	- [Agent (bosh-agent)](https://github.com/cloudfoundry/bosh-agent)
	- Blobstores: [bosh-davcli](https://github.com/cloudfoundry/bosh-davcli), [bosh-s3cli](https://github.com/cloudfoundry/bosh-s3cli), [bosh-gcscli](https://github.com/cloudfoundry/bosh-gcscli)
	- CPI libraries: [bosh-cpi-ruby](https://github.com/cloudfoundry/bosh-cpi-ruby), [bosh-cpi-go](https://github.com/cppforlife/bosh-cpi-go)
	- [Go common packages (bosh-utils)](https://github.com/cloudfoundry/bosh-utils)

## Contributions

Please read the [contributors' guide](https://github.com/cloudfoundry/bosh/blob/master/CONTRIBUTING.md)

## Minimum software requirements

Ruby 3.0.2 or later

## Running the tests

The code and all tests live in the `src` directory. All commands assume that `src` is your current working directory, and that `bundle install` has been run from that directory to install all required Ruby gems.

### Unit Tests

Either run `bundle exec rake unit:spec` or `bundle exec rake unit:spec:parallel`.

The latter will run all unit tests, and should spread the load across all of the logical CPU cores that you have on your system.
