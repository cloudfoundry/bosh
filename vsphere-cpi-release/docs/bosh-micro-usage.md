## Experimental `bosh-micro` usage

#### Caveats: the vSphere cpi release currently only works on Linux, and bosh-micro is still under development.

To start experimenting with vsphere-cpi-release and bosh-micro-cli:

1. [Install the bosh-micro-cli](https://github.com/cloudfoundry/bosh-micro-cli#set-up-a-workstation-for-development)

1. Create a deployment directory

```
mkdir my-micro-deployment
```

1. Create a deployment manifest `manifest.yml` inside the deployment directory with following properties, replacing the YOUR_* values.

```
---
name: microbosh-vsphere

networks:
- name: default
  type: dynamic
  cloud_properties:
    name: YOUR_VSPHERE_NETWORK_NAME

resource_pools:
- name: default
  cloud_properties:
    ram: 2048
    disk: 8096
    cpu: 2
    
cloud_provider:
  properties:
    ntp: [YOUR_NTP_SERVER_ADDRESS]
    director:
      db:
        adapter: sqlite
        database: ':memory:'
    vcenter:
      address: YOUR_VCENTER_HOST_IP
      user: YOUR_VCENTER_USER
      password: YOUR_VCENTER_PASSWORD
      datacenters:
        - name: YOUR_TEST_DATACENTER
          vm_folder: YOUR_VM_FOLDER
          template_folder: YOUR_TEMPLATE_FOLDER
          disk_path: YOUR_DISK_FOLDER
          datastore_pattern: YOUR_DATASTORE_PATTERN
          persistent_datastore_pattern: YOUR_PERSISTENT_DATASTORE_PATTERN
          allow_mixed_datastores: true
          clusters:
            - YOUR_CLUSTER:
                resource_pool: YOUR_RP
```

1. Set the micro deployment

```
bosh-micro deployment my-micro-deployment/manifest.yml
```

1. Create the vsphere-cpi-release tarball

```
git clone git@github.com:cloudfoundry/bosh.git ~/workspace/bosh
cd ~/workspace/bosh/vsphere-cpi-release
bundle
bundle exec rake release:create_vsphere_cpi_release
bundle exec bosh create release --with-tarball $(ls -tr dev_releases/vsphere_cpi/vsphere_cpi-0+dev.*.yml | tail -1)
```

1. Download a vSphere stemcell from the [BOSH Artifacts Page](http://boshartifacts.cloudfoundry.org/file_collections?type=stemcells)

1. Deploy the micro with the downloaded stemcell

```
bosh-micro deploy $(ls -tr dev_releases/vsphere_cpi/vsphere_cpi-0+dev.*.tgz | tail -1) ~/Downloads/stemcell.tgz
```

