# BOSH

Cloud Foundry BOSH is an open source tool for release engineering, deployment, lifecycle management, and monitoring of distributed systems.

This repository is a Bosh Release, providing the necessary binaries and
configuration templates for deploying a new Bosh Director instance, as
instructed by some Bosh deployment manifest, to be applied by some Bosh CLI
invocation or a pre-existing Bosh Director instance.

## Quick start

Bosh is deployed by Bosh, and in order to bootstrap a new Bosh server from
scratch, the Bosh CLI acts as a lightweight Bosh server with the
`bosh create-env` command. Please refer to this
[Quick Start installation guide](https://bosh.io/docs/quick-start/) for more
details.

## See also

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
	- Blobstores: [bosh-davcli](https://github.com/cloudfoundry/bosh-davcli), [bosh-s3cli](https://github.com/cloudfoundry/bosh-s3cli), [bosh-gcscli](https://github.com/cloudfoundry/bosh-gcscli), [bosh-azure-storage-cli](https://github.com/cloudfoundry/bosh-azure-storage-cli)
	- CPI libraries: [bosh-cpi-ruby](https://github.com/cloudfoundry/bosh-cpi-ruby), [bosh-cpi-go](https://github.com/cppforlife/bosh-cpi-go)
	- [Go common packages (bosh-utils)](https://github.com/cloudfoundry/bosh-utils)

## Contributions

Please read the [contributors' guide](https://github.com/cloudfoundry/bosh/blob/master/CONTRIBUTING.md)
