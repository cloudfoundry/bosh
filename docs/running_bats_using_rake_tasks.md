# BATs rake tasks

There are 2 rake tasks that are designed to help with running BATs. They require minumum number of environment variables which are being used to construct deployment manifest. See `Envrionment variables` section below for the full list of environment variables.

## Running BATs against existing director

The following command should be used to run BATs against running director.

```
$ cd bosh
$ bundle exec rake spec:system:existing_micro[<infrastructure>,<hypervisor>,<os_name>,<os_version>,<network_type>,<agent_type>,<light_stemcell_flag>]
```

* <infrastructure> - the type of infrastructure director is running on. (e.g. `aws`, `openstack`, `vsphere`, `vcloud`, `warden`)
* <hypervisor> - the stemcell hypervisor (`hvm` or `xen`)
* <os_name> - the name of OS used in stemcell (`ubuntu` or `centos`)
* <os_version> - the version of OS (e.g. `trusty`)
* <network_type> - the type of network being tested (`manual` or `dynamic`).
* <agent_type> - the agent type that is running on stemcell (e.g. `go`). There used to be `ruby` agent, which is no longer supported by BOSH, so this argument probably will go away soon from rake task.
* <light_stemcell_flag> - the boolean flag that indicates if stemcell type is light (for `aws` stemcells).

There are some infrastructure specific BATs and BATs that depend on network type.

## Running BATs without existing director

The following command will deploy the micro BOSH using tested stemcell first and then run BATs against it.

```
$ cd bosh
$ bundle exec rake spec:system:micro[<infrastructure>,<hypervisor>,<os_name>,<os_version>,<network_type>,<agent_type>,<light_stemcell_flag>]
```

See previos section for arguments meaning.

## Specifying the stemcell that is being tested

`CANDIDATE_BUILD_NUMBER` environment variable determines which stemcell is being tested in rake tasks. 

If it is set then rake tasks will download the public stemcell of the given number of type based on arguments specified in rake tasks (e.g. light aws ubuntu trusty stemcell).

If it is not set the stemcell of version `0000` will be used that is located in `bosh/tmp` folder.