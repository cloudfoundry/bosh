# Tests

Features should always contain unit tests to verify functionality and may need additional tests depending on the feature scope.


## Test Suites

BOSH uses several different types of tests, depending on the scope and subject.


### Unit Tests

Unit tests describe the behavior of individual objects or methods. Each BOSH component has its own unit tests in a `spec/unit` folder.

When working on a specific component, switch to that directory before running `rspec`:

```
# first change into the component's directory
bosh$ cd bosh-director
bosh/bosh-director$ bundle exec rspec
```

To run unit tests for all components, use the `spec:unit` rake task from the project root:

```
bosh$ bundle exec rake spec:unit
```

The CLI must be backwards compatible with Ruby 1.9.3, so when making CLI changes make sure that the CLI tests pass when run with Ruby 1.9.3. All code needs to run on Ruby 2.x.x.

You can also use `./quick-unit-tests.sh` to run all unit tests against a local [Concourse CI](https://concourse.ci/) instance.


### Integration Tests

Integration tests describe communication between BOSH components focusing on the CLI, the Director and the Agent. They are located in the `spec/integration` directory. Run the integration tests with the `spec:integration` rake task:

```
bosh$ bundle exec rake spec:integration
```

You can also use `./quick-integration-tests.sh` to run all integration tests against a local [Concourse CI](https://concourse.ci/) instance.


### Acceptance Tests (BATs)

BATs describe BOSH behavior at the highest level. They often cover infrastructure-specific behavior that is not easily tested at lower levels. BATs verify integration between all BOSH components and infrastructures. They run against a deployed Director and use the CLI to perform tasks. They exercise different BOSH workflows (e.g. deploying for the first time, updating existing deployments, handling broken deployments). The assertions are made against CLI commands exit status, output and state of VMs after performing the command. Since BATs run on real infrastructures, they help verify that specific combinations of the Director and stemcell works.

Some tests in BATs may not be applicable to a given IaaS and can be skipped using tags.
BATs currently supports the following tags:
  - `core`: basic BOSH functionality which all CPIs should implement
  - `persistent_disk`: persistent disk lifecycle tests
  - `vip_networking`: static public address handling
  - `dynamic_networking`: IaaS provided address handling
  - `manual_networking`: BOSH Director specified address handling
  - `root_partition`: BOSH agent repartitioning of unused storage on root volume
  - `multiple_manual_networks`: support for creating machines with multiple network interfaces
  - `raw_ephemeral_storage`: BOSH agent exposes all attached instance storage to deployed jobs
  - `changing_static_ip`: `configure_networks` CPI method support [deprecated]
  - `network_reconfiguration`: `configure_networks` CPI method support [deprecated]

Here is an example of running BATs on vSphere, skipping tests that are not applicable:

```
bundle exec rspec spec --tag ~vip_networking --tag ~dynamic_networking --tag ~root_partition --tag ~raw_ephemeral_storage
```

There are two ways to run BATs - [using rake tasks](running_bats_using_rake_tasks.md) and [manually](running_bats_manually.md).


## Determining which tests suites to run

Sometimes type of infrastructure does not make a difference for changes made. For example if deployment workflow was modified in the Director or some CLI command was modified. In those cases running unit tests and integration tests is enough. In cases when changes relate to specific infrastructure or a CPI it is advised to build and test stemcell of the affected infrastructure.

### Build stemcell

The stemcell building process is described in [bosh-stemcell's README](../bosh-stemcell/README.md). One thing to note is that rake tasks were initially created to run tests on BOSH CI. For development purposes there should be some modifications:

* DO NOT set `CANDIDATE_BUILD_NUMBER` when building stemcell. This will allow you to build stemcell of version `0000` which is understood by rake tasks as a local stemcell.
* Generated stemcells of version `0000` should be put into the `bosh/tmp` directory before running BATs.
