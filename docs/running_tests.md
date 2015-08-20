# Tests

There are four types of tests in BOSH: unit, integration, CPI lifecycle, and acceptance. Each feature should always contain unit tests reflecting the change, and may need additional tests depending on what is changed.

## Available Test Suites

### Unit Tests

Unit tests describe behavior of individual objects or methods. Each BOSH component has its own unit tests in a `spec/unit` folder.

Running individual component unit tests:

```
cd bosh-director # or any other component
bundle exec rspec
```

Running all unit tests:

```
bundle exec rake spec:unit # from the root of the project
```

The CLI is backwards compatible with Ruby 1.9.3, so when making CLI changes make sure that the CLI tests pass when run with Ruby 1.9.3.  All code needs to run on Ruby 2.x.x.

### Integration Tests

Integration tests describe communication between BOSH components focusing on the CLI, the Director and the Agent. They are in the `spec/integration` folder.

Running the integration tests:

```
bundle exec rake spec:integration
```

### CPI Lifecycle Tests

CPI lifecycle tests describe CPI behavior and test integration with the infrastructure. Each test runs through every CPI method in a given configuration.

Running CPI lifecycle tests:

```
cd bosh_vsphere_cpi # or any other CPI
bundle exec rake spec:lifecycle
```

### BOSH Acceptance Tests (BATs)

BATs describe BOSH behavior at the highest level. They often cover infrastructure-specific behavior that is not testable at the lower levels. BATs test integration between all BOSH components and an infrastructure. They run against a deployed Director and use the CLI to perform requests. They exercise different BOSH workflows (e.g. deploying for the first time, updating existing deployment, handling broken deployment). The assertions are made against CLI commands exit status, output and state of VM after performing the command. Since BATs run on a real infrastructure, they confirm that a combination of the Director and stemcell works.

There are two ways to run BATs - [using rake tasks](running_bats_using_rake_tasks.md) and [manually](running_bats_manually.md).

## Determining which tests suites to run

Sometimes type of infrastructure does not make a difference for changes made. For example if deployment workflow was modified in the Director or some CLI command was modified. In those cases running unit tests and integration tests is enough. In cases when changes relate to specific infrastructure or a CPI it is advised to build and test stemcell of the affected infrastructure.

### Build stemcell

The stemcell building process is described in more detail in bosh-stemcell [README](../bosh-stemcell/README.md). One thing to note is that rake tasks were initially created to run tests on BOSH CI. For development purposes there should be made some modifications:

* DO NOT set `CANDIDATE_BUILD_NUMBER` when building stemcell. This will allow you to build stemcell of version `0000` which is being undestood by rake tasks as local stemcell.
* Generated stemcell of version `0000` should be put into `bosh/tmp` folder before running BATs.
