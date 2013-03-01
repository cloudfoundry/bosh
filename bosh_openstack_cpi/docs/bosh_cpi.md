#OpenStack CPI Implementation #
OpenStack CPI is an implementation of BOSH CPI. It allows BOSH to interface with various services in OpenStack like glance, controller and registry. In the sections below we outline the implementation details for each of the method in CPI interface.

##Initialize ##

Implementation of `def initialize(options)` method. 

1. Validate the `options` passed to this method
2. In the second step the parameters are extracted from `options` object to populate the following properties 
	+ `@agent_properties`	
	+ `@openstack_properties`
	+ `@registry_propertiess`
3. Populate the `openstack_params` and connect to remove Nova Service
	1. Instantiate `Fog::Compute` instance
	2. `Fog::Compute::OpenStack` instance is created
	3. A New `Fog::Connection` object connects with the remove Nova Compute Service
4. Populate the `glance_params`and connect to remove Glance service
       1.  Instantiate `Fog::Image` instance
       2.  `Fog::Image::OpenStack` instance is created
       3.  A New `Fog::Connection` object connects with the remove Glance Service
5. Instantiate `Registry_Client`.

Figure below shows the flow of control.

![openstack_cpi_initialize](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_initialize.png)

##Create Stemcell ##

Implementation of method `create_stemcell(image_path, cloud_properties)`
Steps outlined below are the flow control implemented to extract and upload kernel image, ramdisk and stem cell image.

1. Extract parameters from the `cloud_properties`. Check if `kernel_file` parameter exists, instantiate `kernel_image` object
2. Construct `kernel_params`
3. Upload `kernel_image` to glance service by calling the method `upload_image(kernel_params)`
4. If params contain `ramdisk_file` 
5. Instantiate ramdisk_image object and populate `ramdisk_parama`
6. Upload the `ramdisk_image` to glance service by calling `upload(ramdisk_params)`
7. Populate `image_params` for the stem cell to be uploaded to glance service
8. Call the method `upload_image(image_params)` 

Figure below shows the flow control for the method `create_stemcell(image_path, cloud_properties)`

![openstack_cpi_createstemcell](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_createstemcell.png)

##Delete Stemcell

![openstack_cpi_deletestemcell](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_deletestemcell.png)

##Create VM ##

![openstack_cpi_create_vm](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_create_vm.png)

##Delete VM ##

Implementation of `delete_vm(server_id)`. This method deletes the VM created in Nova Compute.

1. Get the `server_id` of the VM to be deleted
	* 1.1, 1.2 : Send the request `get_server_details` to Compute API Server through  `Fog::Connection`
2.  If `server` object returned is not null call `server.destroy`. This will send `delete_server` request to Nova Compute.
	* 2.1, 2.2 : Create and send the `delete_server` request through `Fog::Connection` 
3.  Delete the settings from Registry by calling `delete_settings` method.

Figure below shows the flow control for `delete_vm` method

![openstack_cpi_delete_vm](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_delete_vm.png)

##Create Disk ##

1. Check if size passed is integer, is greater than 1024 and less than 1024*1000, else throw an error
2. Create `volume_params`
3. Call `create()volume_params)` on `Fog::Compute` service
     1. `create_volume` request on `Fog::Volume::OpenStack` 
     2. Opens a `Fog::Connection` request to access the remote service and create a volume.

Figure below shows the flow control of `create_disk` method

![openstack_cpi_create_disk](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_create_disk.png)

##Delete Disk##

This method deletes the volume created in OpenStack Nova Volume 
![openstack_cpi_delete_disk](https://raw.github.com/cloudfoundry/bosh/master/bosh_openstack_cpi/docs/images/openstack_cpi_delete_disk.png)
