# BOSH

BOSH is an acronym for **B**OSH **O**uter **SH**ell. It's composed of the following components

  - `agent/` - agent process that runs in every VM
  - `agent_client/` - agent client library
  - `aws_cpi/` - Cloud Provider Interface for AWS
  - `aws_registry/` - instance registry service for AWS
  - `blobstore_client/` - blobstore client that abstracts the blobstore server
  - `chef_deployer/` - deployer gem (similar to capistrano) except it uses net/ssh+chef_solo+git
  - `cli/` - cli that manages the release process and deployments
  - `common/` - BOSH common gem
  - `cpi/` - Cloud Provider Interface
  - `deployer/` - gem for deploying BOSH using BOSH
  - `director/` - director web service that orchestrates the deployment
  - `encryption/`
  - `git/` - git hooks
  - `health_monitor/` - BOSH health monitor
  - `misc/`
  - `monit_api/` - gem for controlling monit (with auth, groups, etc)
  - `package_compiler/`
  - `rake/` - common Rake files
  - `release/` - release/deployment of BOSH itself
  - `ruby_vim_sdk/` - VMware VIM bindings for Ruby
  - `simple_blobstore_server/` - simple implementation of a blobstore server using local disk
  - `spec/` - integration tests
  - `vsphere_api/` - Cloud Provider Interface for vSphere
