# OpenStack CPI lifecycle tests

Full lifecycle tests are run against a live OpenStack test environment.

### Setup Environment

Set environment variables. Example values can be found in the CI console output.

```
export BOSH_OPENSTACK_AUTH_URL=
export BOSH_OPENSTACK_USERNAME=
export BOSH_OPENSTACK_API_KEY=
export BOSH_OPENSTACK_TENANT=
export BOSH_OPENSTACK_STEMCELL_ID=
export BOSH_OPENSTACK_NET_ID=
export BOSH_OPENSTACK_VOLUME_TYPE=
export BOSH_OPENSTACK_MANUAL_IP=
export BOSH_OPENSTACK_INSTANCE_TYPE=
```

### Execute Tests

```
cd bosh_openstack_cpi
bundle exec rake spec:lifecycle
```
