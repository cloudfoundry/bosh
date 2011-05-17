# BOSH

BOSH is an acronym for **B**OSH **O**uter **SH**ell. It's composed of the following components

  - `agent/` - agent process that runs in every VM
  - `blobstore_client/` - blobstore client that abstracts the blobstore server
  - `chef_deployer/` - deployer gem (similar to capistrano) except it uses net/ssh+chef_solo+git
  - `cli/` - cli that manages the release process and deployments
  - `director/` - director web service that orchestrates the deployment
  - `monit_api/` - gem for controlling monit (with auth, groups, etc)
  - `release/` - release/deployment of BOSH itself
  - `ruby_vim_sdk/` - VMware VIM bindings for Ruby
  - `simple_blobstore_server/` - simple implementation of a blobstore server using local disk
