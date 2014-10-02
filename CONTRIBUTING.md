# Contributing to BOSH

## Contributor License Agreement

Follow these steps to make a contribution to any of our open source repositories:

1. Ensure that you have completed our CLA Agreement for
   [individuals](http://www.cloudfoundry.org/individualcontribution.pdf) or
   [corporations](http://www.cloudfoundry.org/corpcontribution.pdf).

1. Set your name and email (these should match the information on your submitted CLA)

        git config --global user.name "Firstname Lastname"
        git config --global user.email "your_email@example.com"
       
## Set up a workstation for development
We assume you can install packages (brew, apt-get, or equivalent). We include Mac examples here, replace with your package manager of choice.

Bring homebrew index up-to-date:
* `brew update`

Get mysql libraries (needed by the mysql2 gem):
* `brew install mysql`

Get postgresql libraries (needed by the pg gem):
* `brew install postgresql`

Install pg gem manually by specifying your architecture:
* `(sudo) env ARCHFLAGS="-arch x86_64" gem install pg -v '0.15.1'`
 
Get redis:
* `brew install redis`

Get Golang:
* `brew install go`

## General Workflow

Follow these steps to make a contribution to any of our open source repositories:

1. Fork the repository
1. Update submodules (`git submodule update --init`)
1. Create a feature branch (`git checkout -b better_bosh`)
    * Run the tests to ensure that your local environment is
  	  working `bundle && bundle exec rake` (this may take a while)
1. Make changes on the branch:
    * Adding a feature
      1. Add tests for the new feature
      1. Make the tests pass
    * Fixing a bug
      1. Add a test/tests which exercises the bug
      1. Fix the bug, making the tests pass
    * Refactoring existing functionality
      1. Change the implementation
      1. Ensure that tests still pass
        * If you find yourself changing tests after a refactor, consider
          refactoring the tests first

1. Push to your fork (`git push origin better_bosh`) and submit a pull request selecting `develop` as the target branch

We favor pull requests with very small, single commits with a single purpose.

Your pull request is much more likely to be accepted if:

* Your pull request includes tests

* Your pull request is small and focused with a clear message that conveys the intent of your change.

### Tests

There are four types of tests in BOSH: unit, integration, CPI lifecycle, and acceptance.
Each feature should always contain unit tests reflecting the change, and may need additional tests depending on what is changed.

#### Unit Tests

Unit tests describe behavior of individual objects or methods.
Each BOSH component has its own unit tests in a `spec/unit` folder.

Running individual component unit tests:

```
cd bosh-director # or any other component
bundle exec rspec
```

Running all unit tests:

```
bundle exec rake spec:unit
```

#### Integration Tests

Integration tests describe communication between BOSH components.
They are in the `spec/integration` folder.

Running the integration tests:

```
bundle exec rake spec:integration
```

#### CPI Lifecycle Tests

CPI lifecycle tests describe CPI behavior and test integration with the infrastructure.
Each test runs through every CPI method in a given configuration.

Running CPI lifecycle tests:

```
cd bosh_vsphere_cpi # or any other CPI
bundle exec rake spec:lifecycle
```

#### Acceptance Tests (BATs)

BATs describe BOSH behavior at the highest level.
They often include infrastructure-specific behavior that is not testable at the integration level.
BATs test integration between all BOSH components and an infrastructure.

All infrastructures require a stemcell to be specified.

* `STEMCELL_BUILD_NUMBER` (Optional) Stemcell version to look for locally in `<bosh>/tmp/` (defaults to dev build '0000')
* `CANDIDATE_BUILD_NUMBER` - (Optional) Candidate stemcell build number to fetch a remote candidate stemcell from S3 (used for testing in CI)

##### WITH existing microBOSH

The BATs require an existing microbosh to be deployed, and a stemcell built (or downloaded) to test with.
To run the BATs manually, follow the steps in [the `bat` README](bat/README.md) after deploying a microBOSH and downloading or building a stemcell.

##### WITHOUT existing microBOSH

To automatically deploy a microBOSH for you and run the BATs on it, use the `spec:system:micro` rake task.
In order to deploy microBOSH and determine which stemcell to use, set environment variables specific to your infrastructure, as described below.

Example:

```
bundle exec rake spec:system:micro[openstack,kvm,ubuntu,trusty,manual,go]
```

###### OpenStack

* `BOSH_OPENSTACK_NET_ID` - ID of the network on which to deploy microBOSH
* `BOSH_OPENSTACK_MANUAL_IP` - (Optional) Static IP for microBOSH when using VLAN (should be reserved in the bat deployment spec)
* `BOSH_OPENSTACK_VIP_DIRECTOR_IP` - Floating IP for microBOSH
* `BOSH_OPENSTACK_AUTH_URL` - URL to the OpenStack identity service
* `BOSH_OPENSTACK_USERNAME` - OpenStack username
* `BOSH_OPENSTACK_API_KEY` - OpenStack password
* `BOSH_OPENSTACK_TENANT` - OpenStack tenant in which to deploy microBOSH
* `BOSH_OPENSTACK_DEFAULT_SECURITY_GROUP` - Name of the default security group for VMs deployed by microBOSH
* `BOSH_OPENSTACK_DEFAULT_KEY_NAME` - Name of the default SSH keypair for VMs deployed by microBOSH
* `BOSH_OPENSTACK_KEY_NAME` - (Optional) Name of the SSH keypair for deploying microBOSH
* `BOSH_OPENSTACK_PRIVATE_KEY` - Path to the private SSH key for SSHing into VMs deployed by microBOSH
* `BOSH_OPENSTACK_REGION` - OpenStack region in which to deploy microBOSH
* `BOSH_OPENSTACK_REGISTRY_PORT` - (Optional) Local port on which to serve the microBOSH registry service
* `BOSH_OPENSTACK_CONNECTION_TIMEOUT` - (Optional) HTTP connection timeout (in seconds) for talking to the OpenStack API
* `BOSH_OPENSTACK_STATE_TIMEOUT` - (Optional) Timeout (in seconds) to wait for OpenStack resources to reach the desired state
* `BOSH_OPENSTACK_BAT_DEPLOYMENT_SPEC` Path to the BAT deployment spec YAML (input to the BATs deployment manifest erb template)
    * See [the `bat` README](bat/README.md#bat_deployment_spec) for BAT deployment spec examples.
      The director uuid and stemcell properties will be auto-populated by the rake task.

###### vSphere

* `BOSH_VSPHERE_NET_ID` - ID of the network on which to deploy microBOSH
* `BOSH_VSPHERE_MICROBOSH_IP` - (Optional) Static IP for microBOSH (should be reserved in the bat deployment spec)
* `BOSH_VSPHERE_NETMASK` - Netmask for the network on which to deploy microBOSH
* `BOSH_VSPHERE_GATEWAY` - Gateway for the network on which to deploy microBOSH
* `BOSH_VSPHERE_DNS` - DNS server that microBOSH will use to resolve host names
* `BOSH_VSPHERE_NTP_SERVER` - NTP server that microBOSH will use
* `BOSH_VSPHERE_VCENTER` - Hostname or IP of the vCenter Server
* `BOSH_VSPHERE_VCENTER_USER` - vSphere username
* `BOSH_VSPHERE_VCENTER_PASSWORD` - vSphere password
* `BOSH_VSPHERE_VCENTER_DC` - vSphere data center
* `BOSH_VSPHERE_VCENTER_CLUSTER` - vSphere cluster
* `BOSH_VSPHERE_VCENTER_RESOURCE_POOL` - vSphere resource pool name
* `BOSH_VSPHERE_VCENTER_FOLDER_PREFIX` - Folder name prefix under which the microBOSH director stores `_VMs` and `_Templates`
* `BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX` - Folder name prefix under which the microBOSH deployer stores `_VMs` and `_Templates`
* `BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN` - Regular expression pattern that the microBOSH director uses to find datastores
* `BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN` - Regular expression pattern that the microBOSH deployer uses to find datastores
* `BOSH_VSPHERE_BAT_DEPLOYMENT_SPEC` Path to the BAT deployment spec YAML (input to the BATs deployment manifest erb template)
    * See [the `bat` README](bat/README.md#bat_deployment_spec) for BAT deployment spec examples.
      The director uuid and stemcell properties will be auto-populated by the rake task.

## Code Style

As part of the `spec:unit` task we run [RuboCop](http://batsov.com/rubocop/),
which generally enforces the [Ruby Style Guide](https://github.com/bbatsov/ruby-style-guide).

We have a number of exceptions (see the various `.rubocop.yml` files),
and our style is still evolving, however `rake rubocop` is run by Travis
so making these pass will improve the chances that the pull request will
be accepted.
