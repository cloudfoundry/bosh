# BOSH [![Build Status](https://travis-ci.org/cloudfoundry/bosh.png?branch=master)](https://travis-ci.org/cloudfoundry/bosh) [![Code Climate](https://codeclimate.com/github/cloudfoundry/bosh.png)](https://codeclimate.com/github/cloudfoundry/bosh)

Cloud Foundry BOSH is an open source tool chain for release engineering,
deployment and lifecycle management of large scale distributed services.
In this manual we describe the architecture, topology, configuration, and
use of BOSH, as well as the structure and conventions used in packaging
and deployment.

* BOSH Documentation: [http://docs.cloudfoundry.com/docs/running/deploying-cf/](http://docs.cloudfoundry.com/docs/running/deploying-cf/)

## Installing BOSH gems

To install the latest bosh CLI gems:

```
gem install bosh_cli --pre

# Plugin required for deploying MicroBosh
gem install bosh_cli_plugin_micro --pre

# Plugin required for 'bosh aws create' and bootstrap commands
gem install bosh_cli_plugin_aws --pre
```

## Using BOSH CLI and plugins from Git

```
bundle install --binstubs
export PATH=$(pwd)/bin:$PATH
which bosh
```

The `bosh` CLI is now in your `$PATH`, including the `bosh micro` plugin, from the git source; rather than any rubygems you have installed.

# Cloud Foundry Resources

_Cloud Foundry Open Source Platform as a Service_

## Learn

Our documentation, currently a work in progress, is available here:
[http://docs.cloudfoundry.com/](http://docs.cloudfoundry.com/)

## Ask Questions

Questions about the Cloud Foundry Open Source Project can be directed to our Google Groups.

* BOSH Developers: [https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics)
* BOSH Users:[https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics)
* VCAP (Cloud Foundry) Developers: [https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics)

## File a bug

Bugs can be filed using Github Issues within the various repositories of the
[Cloud Foundry](http://github.com/cloudfoundry) components.

## Contributing

Please read the [contributors' guide](CONTRIBUTING.md)
