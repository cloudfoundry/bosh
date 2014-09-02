# BOSH [![Build Status](https://travis-ci.org/cloudfoundry/bosh.png?branch=master)](https://travis-ci.org/cloudfoundry/bosh) [![Code Climate](https://codeclimate.com/github/cloudfoundry/bosh.png)](https://codeclimate.com/github/cloudfoundry/bosh)

* Documentation: [docs.cloudfoundry.org/bosh](http://docs.cloudfoundry.org/bosh)
* IRC: `#bosh` on freenode
* Google groups:
  [bosh-users](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics) &
  [bosh-dev](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics) &
  [vcap-dev](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics) (for CF)

Cloud Foundry BOSH is an open source tool chain for release engineering,
deployment and lifecycle management of large scale distributed services.


## Install

To install the latest BOSH CLI:

```
gem install bosh_cli

# Plugin required for deploying MicroBOSH
gem install bosh_cli_plugin_micro

# Plugin required for 'bosh aws create' and bootstrap commands
gem install bosh_cli_plugin_aws
```


## File a bug

Bugs can be filed using Github Issues within the various repositories of the
[Cloud Foundry](http://github.com/cloudfoundry) components.


## Contributing

Please read the [contributors' guide](CONTRIBUTING.md)
