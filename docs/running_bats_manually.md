# Running BATs manually

You can run BATs manually against an already deployed director.

## Required Environment Variables

Before you can run BAT, you need to set the following environment variables:

```
# DNS name or IP address of the bosh director used for testing (without the scheme)
export BAT_DIRECTOR=

# path to the stemcell you want to use for testing
export BAT_STEMCELL=

# path to the bat yaml file which is used to generate the deployment manifest (see below `bat.yml`)
export BAT_DEPLOYMENT_SPEC=

# password used to ssh to the stemcells
export BAT_VCAP_PASSWORD=

# DNS host or IP where BOSH-controlled PowerDNS server is running, which is required for the DNS tests. For example, if BAT is being run against a MicroBOSH then this value will be the same as BAT_DIRECTOR
export BAT_DNS_HOST=

# the full path to the private key for ssh into the bosh instances
export BOSH_KEY_PATH=

# the name of infrastructure that is used by bosh deployment. Examples: aws, vsphere, openstack, warden.
export BAT_INFRASTRUCTURE=

# the type of networking being used: `dynamic` or `manual`.
export BAT_NETWORKING=

# the path to ssh key, if set bosh ssh will use gateway host and user (optional; required when deployed to vpc)
#export BAT_VCAP_PRIVATE_KEY=

# Run tests with --fail-fast and skip cleanup in case of failure (optional)
#export BAT_DEBUG_MODE=
```

The 'dns' property MUST NOT be specified in the bat deployment spec properties. At all.

## bat.yml

Create bat.yml that is used by BATs to generate manifest. Set `BAT_DEPLOYMENT_SPEC` to point to bat.yml file path.

### AWS

#### manual networking

```yaml
---
cpi: aws
properties:
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-aws-xen-ubuntu-trusty-go_agent
    version: latest
  pool_size: 1
  instances: 1
  vip: 54.54.54.54 # elastic ip for bat deployed VM
  second_static_ip: 10.10.0.31 # Secondary (private) IP to use for reconfiguring networks, must be in the primary network & different from static_ip
  networks:
  - name: default
    static_ip: 10.10.0.30
    cidr: 10.10.0.0/24
    reserved: ['10.10.0.2 - 10.10.0.9']
    static: ['10.10.0.10 - 10.10.0.31']
    gateway: 10.10.0.1
    subnet: subnet-xxxxxxxx # VPC subnet
    security_groups: 'bat' # VPC security groups
  key_name: bosh # (optional) SSH keypair name, overrides the director's default_key_name setting
```

### Openstack

#### dynamic networking

```yaml
---
cpi: openstack
properties:
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-openstack-kvm-ubuntu-trusty-go_agent
    version: latest
  pool_size: 1
  instances: 1
  instance_type: some-ephemeral
  flavor_with_no_ephemeral_disk: no-ephemeral
  vip: 0.0.0.43 # Virtual (public/floating) IP assigned to the bat-release job vm ('static' network), for ssh testing
  networks:
  - name: default
    type: dynamic
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Network ID
      security_groups: ['default'] # security groups assigned to deployed VMs
  key_name: bosh # (optional) SSH keypair name, overrides the director's default_key_name setting
```

#### manual networking

```yaml
---
cpi: openstack
properties:
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-openstack-kvm-ubuntu-trusty-go_agent
    version: latest
  pool_size: 1
  instances: 1
  instance_type: some-ephemeral
  flavor_with_no_ephemeral_disk: no-ephemeral
  vip: 0.0.0.43 # Virtual (public/floating) IP assigned to the bat-release job vm ('static' network), for ssh testing
  second_static_ip: 10.253.3.29 # Secondary (private) IP to use for reconfiguring networks, must be in the primary network & different from static_ip
  networks:
  - name: default
    type: manual
    static_ip: 10.0.1.30 # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Primary Network ID
      security_groups: ['default'] # Security groups assigned to deployed VMs
    cidr: 10.0.1.0/24
    reserved: ['10.0.1.2 - 10.0.1.9']
    static: ['10.0.1.10 - 10.0.1.30']
    gateway: 10.0.1.1
  - name: second # Secondary network for testing jobs with multiple manual networks
    type: manual
    static_ip: 192.168.0.30 # Secondary (private) IP assigned to the bat-release job vm (secondary NIC)
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Secondary Network ID
      security_groups: ['default'] # Security groups assigned to deployed VMs
    cidr: 192.168.0.0/24
    reserved: ['192.168.0.2 - 192.168.0.9']
    static: ['192.168.0.10 - 192.168.0.30']
    gateway: 192.168.0.1
  key_name: bosh # (optional) SSH keypair name, overrides the director's default_key_name setting
```

### vSphere

```yaml
---
cpi: vsphere
properties:
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-vsphere-esxi-ubuntu-trusty-go_agent
    version: latest
  pool_size: 1
  instances: 1
  second_static_ip: 192.168.79.62 # Secondary (private) IP assigned to the bat-release job vm, used for testing network reconfiguration, must be in the primary network & different from static_ip
  networks:
  - name: static
    type: manual
    static_ip: 192.168.79.61 # Primary (private) IP assigned to the bat-release job vm, must be in the static range
    cidr: 192.168.79.0/24
    reserved: ['192.168.79.2 - 192.168.79.50', '192.168.79.128 - 192.168.79.254'] # multiple reserved ranges are allowed but optional
    static: ['192.168.79.60 - 192.168.79.70']
    gateway: 192.168.79.1
    vlan: Network_Name # vSphere network name
```

## EC2 Networking Config

### On EC2 with AWS-provided DHCP networking

Add TCP port `4567` to the **default** security group.

### On EC2 with VPC networking

Create a **bat** security group in the same VPC the BAT_DIRECTOR is running in. Allow inbound access to TCP ports
 `22` and `4567` to the bat security group.

## OpenStack Setup

### Flavors

Create the following flavors:

* `m1.small`
    * ephemeral disk > 6GB
    * root disk big enough for stemcell root partition (currently 3GB)
* `no-ephemeral`
    * ephemeral disk = 0
    * root disk big enough for stemcell root partition (currently 3GB), plus at least 1GB for ephemeral & swap partitions

### Networking Config

Add TCP ports `22` and `4567` to the **default** security group.

## Running BAT

When all of the above is ready, running `bundle exec rake bat:env` will verify environment variables are set correctly.
To run the whole test suite, run `bundle exec rake bat`.
