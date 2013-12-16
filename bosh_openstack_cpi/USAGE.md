# BOSH OpenStack Cloud Provider Interface
# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

For online documentation see: http://rubydoc.info/gems/bosh_openstack_cpi/

## Options

These options are passed to the OpenStack CPI when it is instantiated.

### OpenStack options

The registry options are passed to the Openstack CPI by the BOSH director based on the settings in `director.yml`:

* `auth_url` (required)
  URL of the OpenStack Identity endpoint to connect to
* `username` (required)
  OpenStack user name
* `api_key` (required)
  OpenStack API key
* `tenant` (required)
  OpenStack tenant name
* `region` (optional)
  OpenStack region
* `endpoint_type` (optional)
  OpenStack endpoint type (publicURL (default), adminURL, internalURL)
* `state_timeout` (optional)
  Timeout (in seconds) for OpenStack resources desired state (by default 300)
* `stemcell_public_visibility` (optional)
  Set public visibility for stemcells (true or false (default))
* `connection_options` (optional)
  Hash containing optional connection parameters to the OpenStack API (`ssl_verify_peer`, `omit_default_port`, ...)
* `default_key_name` (required)
  default OpenStack ssh key name to assign to created virtual machines
* `default_security_group` (required)
  default OpenStack security group to assign to created virtual machines

### Registry options

The registry options are passed to the Openstack CPI by the BOSH director based on the settings in `director.yml`:

* `endpoint` (required)
  OpenStack registry URL
* `user` (required)
  OpenStack registry user
* `password` (required)
  OpenStack registry password

### Agent options

The agent options are passed to the OpenStack CPI by the BOSH director based on the settings in `director.yml`:

## Network options

The OpenStack CPI supports these networks types:

* `type` (required)
  can be `dynamic` for a DHCP assigned IP by OpenStack, `manual` for a static IP assigned manually at the BOSH deployment manifest or `vip` to use a Floating IP (which needs to be already allocated)

These options are specified under `cloud_properties` in the `networks` section of a BOSH deployment manifest:

* `security_groups` (optional)
  the OpenStack security groups to assign to VMs. If not specified, it'll use the default security groups set at the OpenStack options

* `net_id` (required for `manual` networks)
  the OpenStack Quantum network UUID to attach as a NIC to VMs.

## Resource pool options

These options are specified under `cloud_properties` in the `resource_pools` section of a BOSH deployment manifest:

* `instance_type` (required)
  which type of instance (OpenStack flavor) the VMs should belong to
* `availability_zone` (optional)
  the OpenStack availability zone the VMs should be created in

## Example

This is a sample of how OpenStack specific properties are used in a BOSH deployment manifest:

    ---
    name: sample
    director_uuid: 38ce80c3-e9e9-4aac-ba61-97c676631b91

    ...

    networks:
      - name: default
        type: dynamic
        cloud_properties:
          security_groups:
            - default
          net_id: 2438bca2-24fa-450f-ae7b-ec2e53b51984
      - name: static
        type: manual
        subnets:
          - name: private
            range: 10.0.1.0/24
            gateway: 10.0.1.1
            reserved:
              - 10.0.1.2 - 10.0.1.9
            static:
              - 10.0.1.10 - 10.0.1.20
            cloud_properties:
              security_groups:
                - default
              net_id: 8d8b84b4-faa6-4605-9fbf-c179bdae4282
      - name: floating
        type: vip
        cloud_properties: {}
    ...

    resource_pools:
      - name: common
        network: default
        size: 1
        stemcell:
          name: bosh-openstack-kvm-ubuntu
          version: latest
        cloud_properties:
          instance_type: m1.small
          availability_zone:

    ...

    properties:
      openstack:
        auth_url: http://pistoncloud.com/:5000/v2.0
        username: christopher
        api_key: QRoqsenPsNGX6
        tenant: Bosh
        region: RegionOne
        endpoint_type: publicURL
        default_key_name: bosh
        default_security_groups: ["bosh"]