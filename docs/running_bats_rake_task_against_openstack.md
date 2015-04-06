# Running BATs rake task against Openstack

Openstack can be configured with manual or dynamic network and BATs are differ for different network type.

## Manual network type

### bat.yml

* Create bat.yml configuration file in the following format:

```
---
cpi: openstack
properties:
  key_name: <KEY_NAME>
  vip: <FLOATING_IP>
  second_static_ip: <SECOND_FLOATING_IP>
  flavor_with_no_ephemeral_disk: <FLAVOR_WITHOUT_EPHEMERAL_DISK>
  networks:
  - name: default
    static_ip: 192.168.111.12
    type: manual
    cloud_properties:
      net_id: <OPENSTACK_NET_ID>
      security_groups: ['default']
    cidr: 192.168.111.0/24
    reserved: ['192.168.111.2 - 192.168.111.10', '192.168.111.14 - 192.168.111.254']
    static: ['192.168.111.11 - 192.168.111.12']
    gateway: 192.168.111.1
  - name: second
    static_ip: 192.168.0.12
    type: manual
    cloud_properties:
      net_id: <OPENSTACK_NET_ID>
      security_groups: ['default']
    cidr: 192.168.0.0/24
    reserved: ['192.168.0.2 - 192.168.0.5', '192.168.0.14 - 192.168.0.254']
    static: ['192.168.0.12']
    gateway: 192.168.0.1
```

* export `BOSH_OPENSTACK_BAT_DEPLOYMENT_SPEC` that point to `bat.yml` created above.


### Environment variables

* `BOSH_OPENSTACK_MICRO_NET_ID` - net ID (e.g. `12a345678-1a2c-4a7b-1afb-1234ab5c6789`)
* `BOSH_OPENSTACK_MANUAL_IP` - static IP of BAT VM (e.g. 192.168.111.10)
* `BOSH_OPENSTACK_VIP_DIRECTOR_IP` - director floating IP
* `BOSH_OPENSTACK_AUTH_URL` - Openstack provider auth URL (e.g. http://132.132.132.132:5000/v2.0)
* `BOSH_OPENSTACK_USERNAME` - Openstack account username
* `BOSH_OPENSTACK_API_KEY` - Openstack account password
* `BOSH_OPENSTACK_TENANT` - Openstack tenant
* `BOSH_OPENSTACK_DEFAULT_KEY_NAME` - ssh key name saved in Openstack account
* `BOSH_OPENSTACK_DEFAULT_SECURITY_GROUP` - the name of security group in Openstack account (e.g. default)
* `BOSH_OPENSTACK_PRIVATE_KEY` - path to public ssh key that has access to Openstack account

### Rake command

```
bundle exec rake spec:system:micro[openstack,kvm,ubuntu,trusty,manual,go]
```


## Dynamic network type

### bat.yml

* Create bat.yml configuration file in the following format:

```
---
cpi: openstack
properties:
  key_name: bosh-ci
  vip: <FLOATING_IP>
  instance_type: <DEFAULT_FLAVOR>
  flavor_with_no_ephemeral_disk: <FLAVOR_WITHOUT_EPHEMERAL_DISK>
  networks:
  - name: default
    type: dynamic
    cloud_properties:
      net_id: <OPENSTACK_NET_ID>
      security_groups: ['<SECURITY_GROUP_NAME>']
```

* export `BOSH_OPENSTACK_BAT_DEPLOYMENT_SPEC` that point to `bat.yml` created above.

### Environment variables

* `BOSH_OPENSTACK_MICRO_NET_ID` - net ID (e.g. `12a345678-1a2c-4a7b-1afb-1234ab5c6789`). Do not set this if Openstack provider does not use specific network (e.g. nebula Openstack provider)
* `BOSH_OPENSTACK_VIP_DIRECTOR_IP` - director floating IP
* `BOSH_OPENSTACK_AUTH_URL` - Openstack provider auth URL (e.g. http://132.132.132.132:5000/v2.0)
* `BOSH_OPENSTACK_USERNAME` - Openstack account username
* `BOSH_OPENSTACK_API_KEY` - Openstack account password
* `BOSH_OPENSTACK_TENANT` - Openstack tenant
* `BOSH_OPENSTACK_DEFAULT_KEY_NAME` - ssh key name saved in Openstack account
* `BOSH_OPENSTACK_DEFAULT_SECURITY_GROUP` - the name of security group in Openstack account (e.g. default)
* `BOSH_OPENSTACK_PRIVATE_KEY` - path to public ssh key that has access to Openstack account


### Rake command

```
bundle exec rake spec:system:micro[openstack,ubuntu,trusty,dynamic,go,false,<disk_format>]
```

* <disk_format> can be either `raw` or `qcow2`

