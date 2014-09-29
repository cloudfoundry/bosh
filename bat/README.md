# BOSH Acceptance Tests


The BOSH Acceptance Tests are meant to be used to verify the commonly used functionality of BOSH.

It requires a BOSH deployment, either a deployed micro bosh stemcell, or a full bosh-release deployment.

Note! If you run BAT via the rake tasks you don't need to setup environment variables below.

## Required Environment Variables

Before you can run BAT, you need to set the following environment variables:
* **BAT_DIRECTOR**: DNS name or IP address of the bosh director used for testing
* **BAT_STEMCELL**: path to the stemcell you want to use for testing
* **BAT_DEPLOYMENT_SPEC**: path to the bat yaml file which is used to generate the deployment manifest (see bat/templates)
* **BAT_VCAP_PASSWORD**: password used to ssh to the stemcells
* **BAT_DNS_HOST**: DNS host or IP where BOSH-controlled PowerDNS server is running, which is required for the DNS tests. For example, if BAT is being run against a MicroBOSH then this value will be the same as BAT_DIRECTOR
* **BOSH_KEY_PATH**: the full path to the private key for ssh into the bosh instances
* **BAT_INFRASTRUCTURE**: the name of infrastructure that is used by bosh deployment. Examples: aws, vsphere, openstack, warden.
* **BAT_NETWORKING**: the type of networking being used: `dynamic` or `manual`.

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
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-openstack-kvm-ubuntu
    version: latest
  key_name: bosh # (optional) SSH keypair name from one of the specified security_groups, overrides the director's default_key_name setting
  vip: 0.0.0.43 # Virtual (public) IP assigned to the bat-release job vm ('static' network), for ssh testing
  networks:
  - name: default
    type: dynamic
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Network ID (uuid)
      security_groups: ['default'] # security groups that identify SSH keypairs
```

On OpenStack with manual networking (requires Quantum):
```yaml
---
cpi: openstack
properties:
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-openstack-kvm-ubuntu
    version: latest
  key_name: bosh # (optional) SSH keypair name from one of the specified security_groups, overrides the director's default_key_name setting
  vip: 0.0.0.43 # Virtual (public) IP assigned to the bat-release job vm ('static' network), for ssh testing
  second_static_ip: 10.253.3.29 # Secondary (private) IP to use for reconfiguring networks, must be in the primary network & different from static_ip
  network:
  - name: default
    type: manual
    static_ip: 10.0.1.30 # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Primary Network ID (uuid)
      security_groups: ['default'] # Security groups that specify SSH keypairs
    cidr: 10.0.1.0/24
    reserved: ['10.0.1.2 - 10.0.1.9']
    static: ['10.0.1.10 - 10.0.1.30']
    gateway: 10.0.1.1
  - name: second # Secondary network for testing jobs with multiple manual networks
    type: manual
    static_ip: 192.168.0.30 # Secondary (private) IP assigned to the bat-release job vm (secondary NIC)
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Secondary Network ID (uuid)
      security_groups: ['default'] # Security groups that specify SSH keypairs
    cidr: 192.168.0.0/24
    reserved: ['192.168.0.2 - 192.168.0.9']
    static: ['192.168.0.10 - 192.168.0.30']
    gateway: 192.168.0.1
```

On vSphere with manual networking:
```yaml
---
cpi: vsphere
properties:
  uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # BAT_DIRECTOR UUID
  stemcell:
    name: bosh-vsphere-esxi-ubuntu
    version: latest
  second_static_ip: 192.168.79.62 # Secondary (private) IP assigned to the bat-release job vm, used for testing network reconfiguration, must be in the primary network & different from static_ip
  network:
  - name: static
    type: manual
    static_ip: 192.168.79.61 # Primary (private) IP assigned to the bat-release job vm, must be in the static range
    cidr: 192.168.79.0/24
    reserved: ['192.168.79.2 - 192.168.79.50', '192.168.79.128 - 192.168.79.254'] # multiple reserved ranges are allowed but optional
    static: ['192.168.79.60 - 192.168.79.70']
    gateway: 192.168.79.1
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
