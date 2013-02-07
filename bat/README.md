# BOSH Acceptance Tests


The BOSH Acceptance Tests are meant to be used to verify the commonly used functionality of BOSH.

It requires a BOSH deployment, either a deployed micro bosh stemcell, or a full bosh-release deployment.

Note! If you don't run BAT via the rake tasks, it is up to you to make sure the environment is setup correctly.

## Required Environment Variables

Before you can run BAT, you need to set the following environment variables:
* **BAT_DIRECTOR**: DNS name or IP address of the bosh director used for testing
* **BAT_STEMCELL**: path to the stemcell you want to use for testing
* **BAT_DEPLOYMENT_SPEC**: path to the bat yaml file which is used to generate the deployment manifest (see bat/templates)
* **BAT_RELEASE_DIR**: path to the bat release repository
* **BAT_VCAP_PASSWORD**: password used to ssh to the stemcells
* **BAT_DNS_HOST** _optional_: DNS host or IP where BOSH-controlled PowerDNS server is running, which is required for the DNS tests. For example, if BAT is being run against a MicroBOSH then this value will be the same as BAT_DIRECTOR

  
## Optional Environment Variables

If BAT_FAST is set, the stemcell & release will not be deleted between each spec. This speeds up testing considerably!

For help troubleshooting test failures, set BAT_DEBUG. For more verbosity, set BAT_DEBUG to "verbose".

If BAT_BOSH_CLI_CONFIG is set, you can change the BOSH CLI config file that is used for tests. The default is to use ./.bosh_cli_config.

If you want the tests to use a specifc bosh cli (versus the default picked up in the shell PATH), set BAT_BOSH_BIN to the `bosh` path.

## Running BAT

When all of the above is ready, you can run `rake bat` which will run the whole test suite.

TODO
* add rake task to download stemcell & bat-release (for full automation)
