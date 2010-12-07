# BOSH

BOSH is an acronym for **B**OSH **O**uter **SH**ell. It's composed of the following components

  - `agent/` - agent process that runs in every VM
  - `blobstore-client/` - blobstore client that abstracts the blobstore server
  - `cli/` - cli that manages the release process and deployments
  - `director/` - director web service that orchestrates the deployment
  - `release/` - release/deployment of BOSH itself
  - `simple_blobstore_server/` - simple implementation of a blobstore server using local disk