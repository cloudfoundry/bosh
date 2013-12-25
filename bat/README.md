# BOSH Acceptance Tests


The BOSH Acceptance Tests are meant to be used to verify the commonly used functionality of BOSH.

It requires a BOSH deployment, either a deployed micro bosh stemcell, or a full bosh-release deployment.

Note! If you don't run BAT via the rake tasks, it is up to you to make sure the environment is setup correctly.

## Required Environment Variables

Before you can run BAT, you need to set the following environment variables:
* **BAT_DIRECTOR**: DNS name or IP address of the bosh director used for testing
* **BAT_STEMCELL**: path to the stemcell you want to use for testing
* **BAT_DEPLOYMENT_SPEC**: path to the bat yaml file which is used to generate the deployment manifest (see bat/templates)
* **BAT_VCAP_PASSWORD**: password used to ssh to the stemcells
* **BAT_DNS_HOST**: DNS host or IP where BOSH-controlled PowerDNS server is running, which is required for the DNS tests. For example, if BAT is being run against a MicroBOSH then this value will be the same as BAT_DIRECTOR
* **BOSH_KEY_PATH**: the full path to the private key for ssh into the bosh instances

The 'dns' property MUST NOT be specified in the bat deployment spec properties. At all.

## Optional Environment Variables

If you want the tests to use a specifc bosh cli (versus the default picked up in the shell PATH), set BAT_BOSH_BIN to the `bosh` path.

## BAT_DEPLOYMENT_SPEC

Example yaml files are below.

On EC2 with AWS-provided DHCP:
```yaml
---
cpi: aws
properties:
  static_ip: 54.235.115.62 # static/elastic IP to use for the bat-release jobs
  uuid: 3aa92242-0423-40f8-97ac-15f8d2f385fa # BAT_DIRECTOR UUID
  pool_size: 1
  stemcell:
    name: bosh-aws-xen-ubuntu
    version: latest
  instances: 1
  key_name: idora # AWS key name if you're running on AWS
  mbus: nats://nats:0b450ada9f830085e2cdeff6@10.42.49.80:4222 # Not used now, but don't remove
```

On EC2 with VPC networking:
```yaml
---
cpi: aws
properties:
  static_ip: 107.23.221.197
  uuid: 93a7819d-ca4e-4636-96dd-35a9f44a579b
  pool_size: 1
  stemcell:
    name: bosh-aws-xen-ubuntu
    version: latest
  instances: 1
  key_name: bosh
  mbus: nats://nats:0b450ada9f830085e2cdeff6@10.42.49.80:4222
  network:
    cidr: 10.10.0.0/24
    reserved:
    - 10.10.0.2 - 10.10.0.9
    static:
    - 10.10.0.10 - 10.10.0.30
    gateway: 10.10.0.1
    subnet: subnet-5088073d
    security_groups:
    - bat
```

On OpenStack with DHCP:
```yaml
---
cpi: openstack
properties:
  static_ip: 54.235.115.62 # floating IP to use for the bat-release jobs
  uuid: 25569986-a7ed-4529-ba84-8a03e2c6c78f # BAT_DIRECTOR UUID
  pool_size: 1
  stemcell:
    name: bosh-openstack-kvm-ubuntu
    version: latest
  instances: 1
  key_name: bosh # OpenStack key name
  mbus: nats://nats:0b450ada9f830085e2cdeff6@10.42.49.80:4222 # Not used now, but don't remove
```

On OpenStack with manual networking (requires Quantum):
```yaml
---
cpi: openstack
properties:
  static_ip: 54.235.115.62 # floating IP to use for the bat-release jobs
  uuid: 25569986-a7ed-4529-ba84-8a03e2c6c78f # BAT_DIRECTOR UUID
  pool_size: 1
  stemcell:
    name: bosh-openstack-kvm-ubuntu
    version: latest
  instances: 1
  key_name: bosh # OpenStack key name
  mbus: nats://nats:0b450ada9f830085e2cdeff6@10.42.49.80:4222
  network:
    cidr: 10.0.1.0/24
    reserved:
    - 10.0.1.2 - 10.0.1.9
    static:
    - 10.0.1.10 - 10.0.1.30
    gateway: 10.0.1.1
    net_id: 4ef0b0ec-58c9-4478-8382-2099da773fdd #
    security_groups:
    - default
```

## EC2 Networking Config

### On EC2 with AWS-provided DHCP networking
Add TCP port `4567` to the **default** security group.

### On EC2 with VPC networking
Create a **bat** security group in the same VPC the BAT_DIRECTOR is running in. Allow inbound access to TCP ports
 `22` and `4567` to the bat security group.

## OpenStack Networking Config

Add TCP ports `22` and `4567` to the **default** security group.

## Running BAT

When all of the above is ready, running `bundle exec rake bat:env` will verify environment variables are set correctly.
To run the whole test suite, run `bundle exec rake bat`.
