# Typical development workflow

## Build stemcell

To test changes that were made in BOSH components the first step is to build stemcell that includes these changes. Sometimes type of infrastructure does not make a difference when for example the changes were made in deployment workflow or not related to infrastructure agent changes. When changes are specific to infrastructure (e.g. in CPI) it is advised to build and test stemcell of the affected infrastructure.

The stemcell building process is described in more detail in bosh-stemcell [README](../bosh-stemcell/README.md). One thing to note is that rake tasks were initially created to run tests on BOSH CI. For development purposes there should be made some modifications:

* DO NOT set `CANDIDATE_BUILD_NUMBER` when building stemcell. This will allow you to build stemcell of version `0000` which is being undestood by rake tasks as local stemcell.

* Generated stemcell of version `0000` should be put into `bosh/tmp` folder before running BATs.

## Run BATs

Set your environment variables depending on infrastructure you are using and run the rake task. See more in [Running BATs](running_bats.md)