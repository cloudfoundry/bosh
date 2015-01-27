# Running BATs rake task against vSphere

## bat.yml

Create bat.yml in the following format:

```
---
cpi: vsphere
properties:
  second_static_ip: <VMWARE_FUSION_IP_PREFIX>.62
  networks:
  - name: static
    type: manual
    static_ip: <VMWARE_FUSION_IP_PREFIX>.61
    cidr: <VMWARE_FUSION_IP_PREFIX>.0/24
    reserved: 
    - <VMWARE_FUSION_IP_PREFIX>.2 - <VMWARE_FUSION_IP_PREFIX>.50
    - <VMWARE_FUSION_IP_PREFIX>.128 - <VMWARE_FUSION_IP_PREFIX>.254
    static:
    - <VMWARE_FUSION_IP_PREFIX>.60 - <VMWARE_FUSION_IP_PREFIX>.70
    gateway: <BOSH_VSPHERE_GATEWAY>
    vlan: <BOSH_VSPHERE_NET_ID>
```

where

* <VMWARE_FUSION_IP_PREFIX> - is a vSphere IP range prefix (e.g. 192.168.79)
* <BOSH_VSPHERE_GATEWAY> - vSphere network gateway (e.g. 192.168.79.1)
* <BOSH_VSPHERE_NET_ID> - vSphere network name (e.g. 'VM Network')

## Environment variables

* `BOSH_VSPHERE_MICROBOSH_IP` - Micro BOSH IP (e.g. 192.168.79.12)
* `BOSH_VSPHERE_NETMASK` - network mask (e.g. 255.255.255.0)
* `BOSH_VSPHERE_GATEWAY` - network gateway (e.g. 192.168.79.1)
* `BOSH_VSPHERE_DNS` - dns address (e.g. 8.8.8.8)
* `BOSH_VSPHERE_NTP_SERVER` - ntp server (e.g. ntp.ubuntu.com)
* `BOSH_VSPHERE_NET_ID` - vSphere network name (e.g. 'VM Network')
* `BOSH_VSPHERE_VCENTER` - vCenter IP adddress
* `BOSH_VSPHERE_VCENTER_USER` - vCenter username
* `BOSH_VSPHERE_VCENTER_PASSWORD` - vCenter password
* `BOSH_VSPHERE_VCENTER_DC` - vSphere datacenter name (e.g. `TEST_DATACENTER`)
* `BOSH_VSPHERE_VCENTER_CLUSTER` - vSphere cluster name (e.g. `TEST_CLUSTER`)
* `BOSH_VSPHERE_VCENTER_RESOURCE_POOL` - vSphere resource pool name (e.g. `TEST_RP`)
* `BOSH_VSPHERE_VCENTER_FOLDER_PREFIX` - VMs and Templates folder prefix - (e.g. `SYSTEM_MICRO_VSPHERE`)
* `BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN` - ephemeral datastore regex pattern (e.g. `datastore`)
* `BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN` - persistent datastore regex pattern (e.g. `datastore`)

## Rake command

```
bundle exec rake spec:system:micro[vsphere,ubuntu,trusty,manual,go,false,ovf]
```
