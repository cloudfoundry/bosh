# Tests

Features should always contain unit tests to verify functionality and may need additional tests depending on the feature scope. Please check the [Workstation Setup](workstation_setup.md) to set the test environment up.


## BOSH Director Ruby app tests

The BOSH Director Ruby web app, as a component, uses several different types
of tests, depending on the scope and subject.


### Unit Tests

Unit tests describe the behavior of individual objects or methods. Each BOSH component has its own unit tests in a `spec/unit` folder.

When working on a specific component, switch to that directory before running `rspec`:

```
# first change into the component's directory
bosh$ cd src/bosh-director
bosh/src/bosh-director$ bundle exec rspec
```

For components like BOSH's director you can specify the database connection via environment variables. If none are given, `sqlite` will be used.

- `DB`: Pick between `postgresql`, `sqlite` and `mysql`.
- `DB_HOST`: Default is `127.0.0.1`.
- `DB_USER`: Default is `root` for MySQL and `postgres` for PostgreSQL.
- `DB_PASSWORD`: Default is `password` for MySQL and none for PostgreSQL.

```
bosh/src$ DB=mysql bundle exec rake spec:unit:director
```

To run unit tests for all components, use the `spec:unit` or `spec:unit:parallel` rake task. The latter will run all unit tests, and should spread the load across all of the logical CPU cores that you have on your system. E.g.:

```
bosh/src$ bundle exec rake spec:unit
```


You can also use a [Concourse CI](https://concourse.ci/) instance with the rake task:

```
bosh/src$ CONCOURSE_TARGET=bosh bundle exec rake fly:unit
```

### Integration Tests

Integration tests describe communication between BOSH components focusing on the CLI, the Director and the Agent. They are located in the `src/spec/integration` directory. To prepare your workstation see [workstation setup docs](workstation_setup.md). Make sure you use the correct java version when running the test, and setup `JAVA_HOME` correctly in case your default system's java installation is not of version 8. Run the integration tests with the `spec:integration` rake task:

```
bosh/src$ bundle exec rake spec:integration
```

In order to run the integration tests in parallel:

```
export NUM_PROCESSES=<n>
```

You can run individual tests by invoking `rspec` directly after setting up the sandbox with `rake spec:integration:install_dependencies` and `rake  spec:integration:download_bosh_agent`. More information about the integration test set up can  be found in the [workstation setup docs](workstation_setup.md).

```
bosh/src$ bundle exec rspec spec/integration/cli_env_spec.rb
```

Run tests against a specific database by setting the `DB` environment variable.

```
bosh/src$ DB=mysql bundle exec rspec spec/integration/cli_env_spec.rb
```

The integration test are run in a sandbox, detailed logs can be found in folder like `src/tmp/integration-tests-workspace/pid-<pid>/sandbox/boshdir/tasks/<n>/debug`.

#### Custom bosh-cli

To use a custom go-cli in integration tests change `bosh` in  `src/spec/support/bosh_go_cli_runner.rb`.
You can also export `BOSH_CLI` to point to a binary.

#### Cleaning the sandbox cache manually

Preparing the sandbox for integration tests caches dependencies like nginx.
To force a recompilation either delete the complete `src/tmp` folder or just the 'work' folder:

```
bosh/src$ rm -fr tmp/integration-nginx-work/
```

#### Running integration test databases in docker

Instead of installing MySQL and PostgreSQL locally use `docker-compose` to spin up containers:

```
cd docs
docker-compose up
```

#### Reset integration test environment

1. Delete blobs/ folder at the root of your bosh repo
2. Do a `bosh sync-blobs`
3. Delete `src/tmp` folder in your repo
4. Run `bundle install` in `src` folder
5. Run `bundle exec rake spec:integration:download_bosh_agent`
6. Run `bundle exec rake spec:integration:install_dependencies`

#### Fly One-off on Concourse

You can also use a [Concourse CI](https://concourse.ci/) instance with the rake task:

```
bosh/src$ CONCOURSE_TARGET=bosh bundle exec rake fly:integration
```

To run integration tests with a custom bosh-cli, build the CLI first and prepare the `out` folder to be a Concourse input.

```
go/src/github.com/cloudfoundry/bosh-cli$ bin/build-linux-amd64
go/src/github.com/cloudfoundry/bosh-cli$ cd out && git init
go/src/github.com/cloudfoundry/bosh-cli/out$ mv bosh bosh-cli-dev-linux-amd64
```

Then execute the integration tests with an additional parameter to set the
directory of the bosh-cli:

```
bosh/src$ CONCOURSE_TARGET=bosh bundle exec rake fly:integration[$HOME/go/src/github.com/cloudfoundry/bosh-cli/out/]
```

To focus on a given spec file you can use the environment variable `SPEC_PATH`

```
bosh/src$ SPEC_PATH=./spec/integration/cancel_tasks_spec.rb CONCOURSE_TARGET=bosh bundle exec rake fly:integration
```


## BOSH Release tests

The BOSH Release

### Run the ERB unit tests

Install the Gem dependencies.
```
bundle install --gemfile=./src/Gemfile
```

Run the ERB unit tests.
```
./scripts/test-unit-erb
```

### Acceptance Tests (BATs)

BATs describe BOSH behavior at the highest level. They often cover infrastructure-specific behavior that is not easily tested at lower levels. BATs verify integration between all BOSH components and infrastructures. They run against a deployed Director and use the CLI to perform tasks. They exercise different BOSH workflows (e.g. deploying for the first time, updating existing deployments, handling broken deployments). The assertions are made against CLI commands exit status, output and state of VMs after performing the command. Since BATs run on real infrastructures, they help verify that specific combinations of the Director and stemcell works.

The BATs live in a separate repository, [cloudfoundry/bosh-acceptance-tests](https://github.com/cloudfoundry/bosh-acceptance-tests). To learn how to run them, please see the README and docs in that repository.

### Release Acceptance Tests (BRATs)

BRATs describe the behavior of BOSH as a BOSH release. They consume a BOSH release and cover specific properties in release. At present, BRATs validate the blobstore access log format as it is CEF format.

Here is an example of running BRATs against a local BOSH director:
```
export BOSH_BINARY_PATH=`which bosh`
export BOSH_DIRECTOR_IP='192.168.50.6'
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int ~/workspace/bosh-deployment/vbox/creds.yml --path /admin_password`
export BOSH_CA_CERT=`bosh int ~/workspace/bosh-deployment/vbox/creds.yml --path /director_ssl/ca`
export BOSH_ENVIRONMENT='vbox'
ginkgo -r src/brats
```

## Determining which tests suites to run

Sometimes type of infrastructure does not make a difference for changes made. For example if deployment workflow was modified in the Director or some CLI command was modified. In those cases running unit tests and integration tests is enough. In cases when changes relate to specific infrastructure or a CPI it is advised to build and test stemcell of the affected infrastructure.

### Build stemcell

The stemcell building process is described in [bosh-stemcell's README](https://github.com/cloudfoundry/bosh-linux-stemcell-builder). One thing to note is that rake tasks were initially created to run tests on BOSH CI. For development purposes there should be some modifications:

* DO NOT set `CANDIDATE_BUILD_NUMBER` when building stemcell. This will allow you to build stemcell of version `0000` which is understood by rake tasks as a local stemcell.
* Generated stemcells of version `0000` should be put into the `bosh/tmp` directory before running BATs.
