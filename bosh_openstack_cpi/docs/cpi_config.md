#OpenStack CPI Configuration

CPI configuration is specified in both the microBOSH deployment manifest and the BOSH release deployment manifest.

microBOSH deployment manifest example:

```
---
name: my-micro

...

cloud:
  plugin: openstack
  properties:
    openstack:
      auth_url: http://0.0.0.0:5000/v2.0
      username: openstack-user
      api_key: openstack-password
      tenant: dev
      region: west-coast
      endpoint_type: publicURL
      state_timeout: 300
      boot_from_volume: false
      stemcell_public_visibility: false
      connection_options: {}
      default_key_name: 
      default_security_groups: 
      wait_resource_poll_interval: 5 
      config_drive: disk 
    registry:
      endpoint: http://0.0.0.0:25777
      user: registry-user
      password: registry-password
    agent: {} # optional agent config

```

BOSH deployment manifest example:

```
---
name: my-bosh

...

properties:
  openstack:
    auth_url: http://0.0.0.0:5000/v2.0
    username: openstack-user
    api_key: openstack-password
    tenant: dev
    region: west-coast
    endpoint_type: publicURL
    state_timeout: 300
    boot_from_volume: false
    stemcell_public_visibility: false
    connection_options: {}
    default_key_name: 
    default_security_groups: 
    wait_resource_poll_interval: 5 
    config_drive: disk 
  registry: 
    address: 0.0.0.0
    http:
      port: 25777
      user: registry-user
      password: registry-password
  agent: {} # optional agent config

```

## OpenStack Properties

* `auth_url` - URL of the OpenStack Identity endpoint to connect to
* `username` - OpenStack user name
* `api_key` - OpenStack API key
* `tenant` - OpenStack tenant name
* `region` - (optional) OpenStack region
* `endpoint_type` - (optional) OpenStack endpoint type (defaults to 'publicURL')
* `state_timeout` - (optional) Timeout (in seconds) for OpenStack resources desired state (defaults to 300)
* `boot_from_volume` - (optional) Boot from volume
* `stemcell_public_visibility` - (optional) Set public visibility for stemcells (defaults to false)
* `connection_options` - Hash containing optional connection parameters to the OpenStack API
* `default_key_name` - Default OpenStack keypair to use when spinning up new vms
* `default_security_groups` - Default OpenStack security groups to use when spinning up new vms
* `wait_resource_poll_interval` - (optional) Changes the delay (in seconds) between each status check to OpenStack when creating a resource
* `config_drive` - (optional) Config drive device (cdrom or disk) to use as metadata service on OpenStack


## Registry Properties

Registry properties are directly set in the microBOSH deployment manifest, but full BOSH has some slight indirection.

microBOSH properties:

* `endpoint` - URI (including scheme, host and port) of the Registry service
* `user` - User to access the Registry
* `password` - Password to access the Registry

BOSH properties:

* `address` - Address of the Registry service
* `http.port` - Port of the Registry to connect to
* `http.user` - User to access the Registry
* `http.password` - Password to access the Registry

## Agent Properties

Agent properties is a hash passed directly to the agent.

