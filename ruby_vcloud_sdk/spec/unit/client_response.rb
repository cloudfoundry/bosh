module VCloudSdk
    module Test
      module Response
        vcd = VCloudSdk::Test::vcd_settings

        USERNAME = vcd["user"]
        ORGANIZATION = vcd["entities"]["organization"]
        OVDC = vcd["entities"]["virtual_datacenter"]
        VAPP_CATALOG_NAME = vcd["entities"]["vapp_catalog"]
        CATALOG_ID = "cfab326c-ab71-445c-bc0b-abf15239de8b"
        VDC_ID = "a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"
        URL = vcd["url"]
        URLN = URI.parse(vcd["url"]).normalize.to_s
        VAPP_TEMPLATE_NAME = "test_vapp_template"
        EXISTING_VAPP_TEMPLATE_NAME  = "existing_template"
        EXISTING_VAPP_TEMPLATE_ID = "085f0844-9feb-43bd-b1df-3260218f5cb6"
        EXISTING_VAPP_NAME  = "existing_vapp"
        EXISTING_VAPP_ID = "085f0844-9feb-43bd-b1df-3260218f5cb2"
        EXISTING_VAPP_URN = "urn:vcloud:vapp:085f0844-9feb-43bd-b1df-3260218f5cb2"
        EXISTING_VAPP_RESOLVER_URL = "#{URL}/api/entity/#{EXISTING_VAPP_URN}"
        EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID = "521f9fc3-410f-433c-b877-1d072478c3c5"
        INSTANTIATED_VM_ID = "048e8cd8-adc8-49c6-80ee-a430ecf8f246"
        CPU = "2"
        MEMORY = "128"
        VM_NAME = "vm1"
        VAPP_TEMPLATE_VM_URL = "#{URL}/api/vAppTemplate/vm-49acc996-0ee4-4b36-a5b5-822f3042e26c"
        CHANGED_VM_NAME = "changed_vm1"
        CHANGED_VM_DESCRIPTION = "changed_description"
        CHANGED_VM_CPU = "3"
        CHANGED_VM_MEMORY = "712"
        CHANGED_VM_DISK = "3072"
        MEDIA_NAME = "test_media"

        EXISTING_MEDIA_NAME = "existing_test_media"
        EXISTING_MEDIA_ID = "abcf0844-9feb-43bd-b1df-3262218f5cb2"
        EXISTING_MEDIA_CATALOG_ID = "cacef844-9feb-43bd-b1df-3262218f5cb2"

        VAPP_ID = "c032c1a3-21a2-4ac2-8e98-0cc29229e10c"
        VM1_ID = "49acc996-0ee4-4b36-a5b5-822f3042e26c"
        LOGIN_LINK = "#{URL}/api/sessions"
        VAPP_NAME = "test_vapp"

        ORG_NETWORK_NAME = "vcap_net"
        ORG_NETWORK_ID = "0ae50dfd-a5eb-44e9-9c26-5c1a00a3e1a4"
        VAPP_NETWORK_NAME = "vcap_net"

        INDY_DISK_NAME = "indy_disk_1"
        INDY_DISK_ID = "447e14ee-52a7-45ef-93ba-666f7879490d"
        INDY_DISK_URL = "#{URL}/api/disk/#{INDY_DISK_ID}"
        INDY_DISK_SIZE = 200
        SCSI_CONTROLLER_ID = "2"


        SESSION = (File.read(Test.spec_asset("session.xml")) %
          [USERNAME, ORGANIZATION, URL, URL, URL, URL, URL]).strip

        ADMIN_VCLOUD_LINK = "#{URL}/api/admin/"

        VCLOUD_RESPONSE = (File.read(Test.spec_asset("vcloud_response.xml")) %
          [URL, URL, ORGANIZATION, URL, URL, URL, URL, URL, URL, URL,
          URL, URL, URL, URL, URL, URL, URL, URL, URL, URL,
          URL, URL, URL, URL, URL, URL, URL, URL, URL, URL,
          URL, URL, URL, URL, URL, URL, URL, URL, URL, URL,
          URL, URL, URL, URL, URL, URL, URL, URL, URL, URL]).strip

        ADMIN_ORG_LINK = "#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"

        ADMIN_ORG_RESPONSE = (File.read(Test.spec_asset("admin_org_response.xml")) %
          [ORGANIZATION, URL, URL, URL, URL, URL, URL, URL, URL, URL, URL, URL,
          ORGANIZATION, URL, URL, URL, URL, URL, URL, URL, URL, URL, URL, URL,
          URL, URL, URL, URL, URL, URL, URL, URL, URL, VAPP_CATALOG_NAME, URL,
          CATALOG_ID, OVDC, URL, VDC_ID]).strip

        ORG_NETWORK_LINK = "#{URL}/api/network/#{ORG_NETWORK_ID}"

        VDC_LINK = "#{URL}/api/vdc/#{VDC_ID}"

        MEDIA_UPLOAD_LINK  = "#{URL}/api/vdc/#{VDC_ID}/media"

        VDC_INDY_DISKS_LINK = "#{URL}/api/vdc/#{VDC_ID}/disk"

        VDC_RESPONSE = (File.read(Test.spec_asset("vdc_response.xml")) %
          [OVDC, VDC_ID, URL, VDC_ID, URL, URL, URL, VDC_ID, URL, VDC_ID,
          MEDIA_UPLOAD_LINK, URL, VDC_ID, URL, VDC_ID, URL, VDC_ID, URL, VDC_ID,
          URL, VDC_ID, URL, VDC_ID, VDC_INDY_DISKS_LINK, EXISTING_VAPP_NAME,
          URL, EXISTING_VAPP_ID, EXISTING_VAPP_TEMPLATE_NAME, URL,
          EXISTING_VAPP_TEMPLATE_ID, EXISTING_MEDIA_NAME, URL, EXISTING_MEDIA_ID,
          INDY_DISK_NAME, INDY_DISK_URL, ORG_NETWORK_NAME, ORG_NETWORK_LINK]).strip

        VDC_VAPP_UPLOAD_LINK = "#{URL}/api/vdc/#{VDC_ID}/action/uploadVAppTemplate"


        VAPP_TEMPLATE_UPLOAD_REQUEST = (File.read(Test.spec_asset(
          "vapp_template_upload_request.xml")) % [VAPP_TEMPLATE_NAME]).strip

        VAPP_TEMPLATE_UPLOAD_OVF_WAITING_RESPONSE = (File.read(Test.spec_asset(
          "vapp_template_upload_response.xml")) % [VAPP_TEMPLATE_NAME, URL,
          URL, URL, VDC_ID, URL, URL, USERNAME, URL, URL, URL, URL]).strip

        VAPP_TEMPLATE_LINK = "#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c"

        VAPP_TEMPLATE_UPLOAD_OVF_LINK = "#{URL}/transfer/22467867-7ada-4a55-a9cb-e05aa30a4f96/descriptor.ovf"

        VAPP_TEMPLATE_NO_DISKS_RESPONSE = (File.read(Test.spec_asset(
          "vapp_template_no_disk_response.xml")) % [VAPP_TEMPLATE_NAME, URL,
          URL, URL, VDC_ID, URL, URL, URL, USERNAME, URL, URL, URL, URL]).strip

        VAPP_TEMPLATE_DISK_UPLOAD_1 = "#{URL}/transfer/62137697-8d51-4df6-9689-0b7f84ccc096/haoUnOS2VMs-disk1.vmdk"

        VAPP_TEMPLATE_UPLOAD_COMPLETE = (File.read(Test.spec_asset(
          "vapp_template_upload_complete.xml")) % [VAPP_TEMPLATE_NAME, VAPP_ID,
          URL, VAPP_ID, URL, URL, VDC_ID, URL, VAPP_ID, VAPP_TEMPLATE_NAME,
          VAPP_ID, URL, URL, VAPP_TEMPLATE_NAME, URL, VAPP_ID, USERNAME, URL,
          USERNAME, URL, VAPP_TEMPLATE_NAME, URL, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID]).strip

        VAPP_TEMPLATE_UPLOAD_FAILED = (File.read(Test.spec_asset(
          "vapp_template_upload_failed.xml")) % [VAPP_TEMPLATE_NAME, VAPP_ID,
          URL, VAPP_ID, URL, URL, VDC_ID, URL, VAPP_ID, VAPP_TEMPLATE_NAME,
          VAPP_ID, URL, URL, VAPP_TEMPLATE_NAME, URL, VAPP_ID, USERNAME, URL,
          USERNAME, URL, VAPP_TEMPLATE_NAME, URL, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID]).strip

        CATALOG_LINK = "#{URL}/api/admin/catalog/#{CATALOG_ID}"

        CATALOG_ADD_ITEM_LINK = "#{URL}/api/catalog/#{CATALOG_ID}/catalogItems"

        EXISTING_MEDIA_LINK = "#{URL}/api/media/#{EXISTING_MEDIA_ID}"

        EXISTING_MEDIA_BUSY_RESPONSE = (File.read(Test.spec_asset(
          "existing_media_busy_response.xml")) % [EXISTING_MEDIA_NAME,
          EXISTING_MEDIA_ID, EXISTING_MEDIA_LINK, URL, EXISTING_MEDIA_NAME,
          EXISTING_MEDIA_ID, URL, URL, EXISTING_MEDIA_NAME, URL,
          EXISTING_MEDIA_ID, URL, URL, URL, USERNAME, URL]).strip

        EXISTING_MEDIA_DONE_RESPONSE = (File.read(Test.spec_asset(
          "existing_media_done_response.xml")) % [EXISTING_MEDIA_NAME,
          EXISTING_MEDIA_ID, EXISTING_MEDIA_LINK, URL, URL, EXISTING_MEDIA_LINK,
          URL, EXISTING_MEDIA_ID, URL, EXISTING_MEDIA_ID, URL,
          EXISTING_MEDIA_ID, USERNAME, URL]).strip

        EXISTING_MEDIA_CATALOG_ITEM_LINK = "#{URL}/api/catalogItem/#{EXISTING_MEDIA_CATALOG_ID}"

        EXISTING_MEDIA_CATALOG_ITEM = (File.read(Test.spec_asset(
          "existing_media_catalog_item.xml")) % [EXISTING_MEDIA_NAME,
          EXISTING_MEDIA_CATALOG_ID, EXISTING_MEDIA_CATALOG_ITEM_LINK, URL, URL,
          EXISTING_MEDIA_CATALOG_ID, URL, EXISTING_MEDIA_CATALOG_ID, URL,
          EXISTING_MEDIA_CATALOG_ID, EXISTING_MEDIA_NAME,
          EXISTING_MEDIA_LINK]).strip

        EXISTING_MEDIA_DELETE_TASK_ID = "e0491c4a-d9e9-4b86-8c46-2d7736b8f82a"

        EXISTING_MEDIA_DELETE_TASK_LINK = "#{URL}/api/task/#{EXISTING_MEDIA_DELETE_TASK_ID}"

        EXISTING_MEDIA_DELETE_TASK_DONE = (File.read(Test.spec_asset(
          "existing_media_delete_task_done.xml")) %
          [EXISTING_MEDIA_DELETE_TASK_ID, EXISTING_MEDIA_DELETE_TASK_LINK, URL,
          EXISTING_MEDIA_DELETE_TASK_ID, EXISTING_MEDIA_LINK, USERNAME, URL,
          URL]).strip

        CATALOG_RESPONSE = (File.read(Test.spec_asset("catalog_response.xml")) %
          [VAPP_CATALOG_NAME, CATALOG_ID, URL, CATALOG_ID, URL, URL, URL,
          CATALOG_ID, URL, CATALOG_ID, CATALOG_ADD_ITEM_LINK, URL, CATALOG_ID,
          URL, CATALOG_ID, URL, CATALOG_ID, URL, EXISTING_VAPP_TEMPLATE_NAME,
          URL, EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID, EXISTING_MEDIA_NAME,
          EXISTING_MEDIA_CATALOG_ITEM_LINK]).strip

        CATALOG_ADD_VAPP_REQUEST = (File.read(Test.spec_asset(
          "catalog_add_vapp_request.xml")) % [VAPP_TEMPLATE_NAME,
          VAPP_TEMPLATE_NAME, VAPP_ID, URL, VAPP_ID]).strip

        CATALOG_ADD_ITEM_RESPONSE = (File.read(Test.spec_asset(
          "catalog_add_item_response.xml")) % [VAPP_TEMPLATE_NAME, URL, URL, URL,
          CATALOG_ID, URL, URL, URL, VAPP_TEMPLATE_NAME, URL, VAPP_ID]).strip

        CATALOG_ITEM_ADDED_RESPONSE = (File.read(Test.spec_asset(
          "catalog_item_added_response.xml")) % [VAPP_CATALOG_NAME, CATALOG_ID,
          URL, CATALOG_ID, URL, URL, URL, CATALOG_ID, URL, CATALOG_ID, URL,
          CATALOG_ID, URL, CATALOG_ID, URL, CATALOG_ID, URL, CATALOG_ID, URL,
          EXISTING_VAPP_TEMPLATE_NAME, URL, EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID,
          VAPP_TEMPLATE_NAME, URL]).strip

        CATALOG_ITEM_VAPP_LINK = "#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"

        FINALIZE_UPLOAD_TASK_ID = "91bd4b57-598e-4753-8274-1172c7195468"

        FINALIZE_UPLOAD_TASK_LINK = "#{URL}/api/task/#{FINALIZE_UPLOAD_TASK_ID}"

        FINALIZE_UPLOAD_TASK_RESPONSE = (File.read(Test.spec_asset(
          "finalize_upload_task_response.xml")) % [VAPP_TEMPLATE_NAME, VAPP_ID,
          FINALIZE_UPLOAD_TASK_ID, URL, FINALIZE_UPLOAD_TASK_ID, URL, URL,
          FINALIZE_UPLOAD_TASK_ID, VAPP_TEMPLATE_NAME, URL, VAPP_ID, URL,
          URL]).strip()

        FINALIZE_UPLOAD_TASK_DONE_RESPONSE = (File.read(Test.spec_asset(
          "finalize_upload_task_done_response.xml")) % [VAPP_TEMPLATE_NAME,
          VAPP_ID, FINALIZE_UPLOAD_TASK_ID, URL, FINALIZE_UPLOAD_TASK_ID, URL,
          URL, FINALIZE_UPLOAD_TASK_ID, VAPP_TEMPLATE_NAME, URL, VAPP_ID, URL,
          URL]).strip

        VAPP_TEMPLATE_READY_RESPONSE = (File.read(Test.spec_asset(
          "vapp_template_ready_response.xml")) % [VAPP_TEMPLATE_NAME, VAPP_ID,
          URL, VAPP_ID, URL, URL, VDC_ID, URL, VAPP_ID, URL, VAPP_ID, URL,
          VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, URL, URL, VAPP_ID, URL, URL,
          URL, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL,
          VAPP_ID, URL, VAPP_ID]).strip

        VAPP_TEMPLATE_DELETE_TASK_ID = "909835c2-b4c4-4bce-b3da-d33650e25de2"

        VAPP_TEMPLATE_DELETE_TASK_LINK = "#{URL}/api/task/#{VAPP_TEMPLATE_DELETE_TASK_ID}"

        VAPP_TEMPLATE_DELETE_RUNNING_TASK = (File.read(Test.spec_asset(
          "vapp_template_delelete_running_task.xml")) % [VAPP_ID,
          VAPP_TEMPLATE_DELETE_TASK_ID, URL, VAPP_TEMPLATE_DELETE_TASK_ID, URL,
          URL, VAPP_TEMPLATE_DELETE_TASK_ID, URL, URL, URL]).strip

        VAPP_TEMPLATE_DELETE_DONE_TASK = (File.read(Test.spec_asset(
          "vapp_template_delelete_done_task.xml")) % [VAPP_ID,
          VAPP_TEMPLATE_DELETE_TASK_ID, URL, VAPP_TEMPLATE_DELETE_TASK_ID, URL,
          URL, URL, URL]).strip

        DELETED_VAPP_NAME = "already_deleted"

        EXISTING_VAPP_LINK = "#{URL}/api/vApp/vapp-#{EXISTING_VAPP_ID}"

        VAPP_TEMPLATE_INSTANTIATE_LINK = "#{URL}/api/vdc/#{VDC_ID}/action/instantiateVAppTemplate"

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_REQUEST = (File.read(Test.spec_asset(
          "vapp_template_instantiate_request.xml")) % [VAPP_NAME, URL,
          EXISTING_VAPP_TEMPLATE_ID, EXISTING_VAPP_TEMPLATE_ID]).strip

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_WITH_LOCALITY_REQUEST = (File.read(
          Test.spec_asset("vapp_template_instantiate_with_locality_request.xml")) %
          [VAPP_NAME, URL, EXISTING_VAPP_TEMPLATE_ID, EXISTING_VAPP_TEMPLATE_ID,
          VM_NAME, VAPP_TEMPLATE_VM_URL, INDY_DISK_NAME, INDY_DISK_URL]).strip

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID = "37be6f4c-69a8-4f80-ba94-271175967a68"

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_LINK = "#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}"

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_START_RESPONSE = (File.read(Test.spec_asset(
          "existing_vapp_template_instantiate_task_start_response.xml")) % [
          VAPP_NAME, VAPP_ID, EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, VAPP_NAME, URL, VAPP_ID,
          USERNAME, URL, ORGANIZATION, URL]).strip

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_SUCCESS_RESPONSE = (File.read(
          Test.spec_asset("existing_vapp_template_instantiate_task_success_response.xml")) %
          [VAPP_NAME, VAPP_ID, EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, VAPP_NAME, URL, VAPP_ID,
          USERNAME, URL, ORGANIZATION, URL]).strip

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ERROR_RESPONSE = (File.read(Test.spec_asset(
          "existing_vapp_template_instantiate_task_error_response.xml")) %
          [VAPP_NAME, VAPP_ID, EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, VAPP_NAME, URL, VAPP_ID,
          USERNAME, URL, ORGANIZATION, URL]).strip

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_RESPONSE  = (File.read(Test.spec_asset(
          "existing_vapp_template_instantiate_response.xml")) % [VAPP_NAME,
          VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VDC_ID, URL, VAPP_ID, URL,
          VAPP_ID, VAPP_NAME, VAPP_ID, EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID,
          URL, EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, URL,
          EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID, VAPP_NAME, URL, VAPP_ID,
          URL, ORGANIZATION, URL, URL]).strip

        EXISTING_VAPP_TEMPLATE_CATALOG_URN = "urn:vcloud:catalogitem:#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"
        EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_URL = "#{URL}/api/entity/#{EXISTING_VAPP_TEMPLATE_CATALOG_URN}"
        EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_LINK = "#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"

        EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_RESPONSE = (File.read(Test.spec_asset(
          "existing_vapp_template_item_response.xml")) %
          [EXISTING_VAPP_TEMPLATE_NAME, URL, URL, URL, CATALOG_ID, URL,
          EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID, URL,
          EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID, URL,
          EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID, EXISTING_VAPP_TEMPLATE_NAME,
          URL, EXISTING_VAPP_TEMPLATE_ID]).strip

        VAPP_TEMPLATE_CATALOG_URN = "urn:vcloud:catalogitem:39a8f899-0f8e-40c4-ac68-66b2688833bc"
        VAPP_TEMPLATE_CATALOG_RESOLVER_URL = "#{URL}/api/entity/#{VAPP_TEMPLATE_CATALOG_URN}"
        VAPP_TEMPLATE_CATALOG_ITEM_LINK = "#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"

        EXISTING_VAPP_TEMPLATE_LINK = "#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"

        EXISTING_VAPP_TEMPLATE_READY_RESPONSE = (File.read(Test.spec_asset(
          "existing_vapp_template_ready_response.xml")) % [VAPP_TEMPLATE_NAME,
          EXISTING_VAPP_TEMPLATE_ID, URL, EXISTING_VAPP_TEMPLATE_ID, URL, URL,
          VDC_ID, URL, EXISTING_VAPP_TEMPLATE_ID, URL, EXISTING_VAPP_TEMPLATE_ID,
          URL, EXISTING_VAPP_TEMPLATE_ID, URL, EXISTING_VAPP_TEMPLATE_ID, URL,
          EXISTING_VAPP_TEMPLATE_ID, URL, VM1_ID, URL, VM1_ID, URL,
          EXISTING_VAPP_TEMPLATE_ID, URL, VM1_ID, URL, VM1_ID, URL, VM1_ID,
          VM1_ID, URL, EXISTING_VAPP_TEMPLATE_ID, URL, EXISTING_VAPP_TEMPLATE_ID,
          URL, EXISTING_VAPP_TEMPLATE_ID, URL, EXISTING_VAPP_TEMPLATE_ID, URL,
          EXISTING_VAPP_TEMPLATE_ID, URL, EXISTING_VAPP_TEMPLATE_ID]).strip

        INSTANTIATED_VAPP_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}"

        INSTANTIATED_VM_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"

        INSTANTIATED_VM_NETWORK_SECTION_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/networkConnectionSection/"

        INSTANTIATED_VAPP_POWER_ON_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}/power/action/powerOn"

        INSTANTIATED_VAPP_POWER_OFF_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}/power/action/powerOff"

        INSTANTIATED_VAPP_POWER_REBOOT_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}/power/action/reboot"

        INSTANTIATED_VAPP_UNDEPLOY_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}/action/undeploy"

        INSTANTIATED_VAPP_DISCARD_STATE_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}/action/discardSuspendedState"

        INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK = "#{URL}/api/vApp/vapp-#{VAPP_ID}/networkConfigSection/"

        INSTANTIATED_VM_INSERT_MEDIA_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/insertMedia"

        INSTANTIATED_VM_INSERT_MEDIA_TASK_ID = "dd3a1c3c-6e4a-4783-9e18-d95e65dd260c"

        INSTANTIATED_VM_INSERT_MEDIA_TASK_LINK = "#{URL}/api/task/#{INSTANTIATED_VM_INSERT_MEDIA_TASK_ID}"

        INSTANTIATED_VM_INSERT_MEDIA_TASK_DONE = (File.read(Test.spec_asset(
          "instantiated_vm_insert_media_task_done.xml")) %
          [INSTANTIATED_VM_INSERT_MEDIA_TASK_ID,
          INSTANTIATED_VM_INSERT_MEDIA_TASK_LINK, URL,
          INSTANTIATED_VM_INSERT_MEDIA_TASK_ID, URL, URL, URL]).strip

        INSTANTIATED_VM_ATTACH_DISK_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/disk/action/attach"

        INSTANTIATED_VM_DETACH_DISK_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/disk/action/detach"

        INSTANTIAED_VAPP_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vapp_response.xml")) % [VAPP_ID, URL, VAPP_ID,
          INSTANTIATED_VAPP_POWER_ON_LINK, URL, VAPP_ID, URL, VAPP_ID, URL,
          VAPP_ID, URL, VAPP_ID, URL, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID, INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_LINK, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_INSERT_MEDIA_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ATTACH_DISK_LINK, INSTANTIATED_VM_DETACH_DISK_LINK, URL,
          INSTANTIATED_VM_ID, URL, VAPP_ID, URL, INSTANTIATED_VM_ID,
          SCSI_CONTROLLER_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_NETWORK_SECTION_LINK,
          INSTANTIATED_VM_NETWORK_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID]).strip

        INSTANTIAED_VAPP_ON_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vapp_on_response.xml")) % [VAPP_ID, URL, VAPP_ID,
          INSTANTIATED_VAPP_POWER_OFF_LINK, INSTANTIATED_VAPP_POWER_REBOOT_LINK,
          INSTANTIATED_VAPP_UNDEPLOY_LINK, URL, VAPP_ID, URL, VAPP_ID, URL,
          VAPP_ID, URL, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_LINK, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_INSERT_MEDIA_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ATTACH_DISK_LINK, INSTANTIATED_VM_DETACH_DISK_LINK,
          URL, INSTANTIATED_VM_ID, URL, VAPP_ID, URL, INSTANTIATED_VM_ID,
          SCSI_CONTROLLER_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_NETWORK_SECTION_LINK,
          INSTANTIATED_VM_NETWORK_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID]).strip


        INSTANTIAED_VAPP_POWERED_OFF_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vapp_off_response.xml")) % [VAPP_NAME, VAPP_ID, URL,
          VAPP_ID, INSTANTIATED_VAPP_POWER_ON_LINK, INSTANTIATED_VAPP_POWER_OFF_LINK,
          INSTANTIATED_VAPP_UNDEPLOY_LINK, URL, VAPP_ID, URL, VAPP_ID, URL,
          VAPP_ID, URL, VAPP_ID, URL, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID, INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_LINK, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_INSERT_MEDIA_LINK, URL,
          INSTANTIATED_VM_ID, INSTANTIATED_VM_ATTACH_DISK_LINK,
          INSTANTIATED_VM_DETACH_DISK_LINK, URL, INSTANTIATED_VM_ID, URL, VAPP_ID,
          URL, INSTANTIATED_VM_ID, SCSI_CONTROLLER_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_NETWORK_SECTION_LINK,
          INSTANTIATED_VM_NETWORK_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID]).strip


        INSTANTIATED_SUSPENDED_VAPP_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_suspended_vapp_response.xml")) % [VAPP_ID, URL, VAPP_ID,
          INSTANTIATED_VAPP_POWER_ON_LINK, URL, VAPP_ID, URL, VAPP_ID, URL,
          VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL,
          URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID, URL, VAPP_ID,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_LINK, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_INSERT_MEDIA_LINK, URL,
          INSTANTIATED_VM_ID, INSTANTIATED_VM_ATTACH_DISK_LINK,
          INSTANTIATED_VM_DETACH_DISK_LINK, URL, INSTANTIATED_VM_ID, URL, VAPP_ID,
          URL, INSTANTIATED_VM_ID, SCSI_CONTROLLER_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_NETWORK_SECTION_LINK,
          INSTANTIATED_VM_NETWORK_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID]).strip

        INSTANTIATED_VAPP_DELETE_TASK_ID = "2637f9de-4a68-4829-9515-469788a4e36a"

        INSTANTIATED_VAPP_DELETE_TASK_LINK = "#{URL}/api/task/#{INSTANTIATED_VAPP_DELETE_TASK_ID}"

        INSTANTIATED_VAPP_DELETE_RUNNING_TASK = (File.read(Test.spec_asset(
          "instantiated_vapp_delelete_running_task.xml")) %
          [VAPP_ID, INSTANTIATED_VAPP_DELETE_TASK_ID, URL,
          INSTANTIATED_VAPP_DELETE_TASK_ID, URL, URL,
          INSTANTIATED_VAPP_DELETE_TASK_ID, URL, URL, URL]).strip

        INSTANTIATED_VAPP_DELETE_DONE_TASK = (File.read(Test.spec_asset(
          "instantiated_vapp_delelete_done_task.xml")) % [VAPP_ID,
          INSTANTIATED_VAPP_DELETE_TASK_ID, URL,
          INSTANTIATED_VAPP_DELETE_TASK_ID, URL, URL, URL, URL]).strip

        INSTANTIATED_VAPP_POWER_ON_TASK_ID = "d202bc01-3a7e-4683-adac-bfc76fdf1293"

        INSTANTIATED_VAPP_POWER_ON_TASK_LINK = "#{URL}/api/task/#{INSTANTIATED_VAPP_POWER_ON_TASK_ID}"

        INSTANTED_VAPP_POWER_TASK_RUNNING = (File.read(Test.spec_asset(
          "instantiated_vapp_power_task_running.xml")) %
          [INSTANTIATED_VAPP_POWER_ON_TASK_ID,
          INSTANTIATED_VAPP_POWER_ON_TASK_LINK, URL,
          INSTANTIATED_VAPP_POWER_ON_TASK_ID, VAPP_NAME, URL, USERNAME, URL,
          ORGANIZATION, URL]).strip

        INSTANTED_VAPP_POWER_TASK_SUCCESS = (File.read(Test.spec_asset(
          "instantiated_vapp_power_task_success.xml")) %
          [INSTANTIATED_VAPP_POWER_ON_TASK_ID, INSTANTIATED_VAPP_POWER_ON_TASK_LINK,
          URL, INSTANTIATED_VAPP_POWER_ON_TASK_ID, VAPP_NAME, URL, USERNAME,
          URL, ORGANIZATION, URL]).strip

        INSTANTIATED_VM_CPU_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"

        INSTANTIATED_VM_CPU_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vm_cpu_response.xml")) % [URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID]).strip

        INSTANTIATED_VM_MEMORY_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"

        INSTANTIATED_VM_MEMORY_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vm_memory_response.xml")) % [URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID]).strip

        INSTANTIATED_VM_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vm_response.xml")) % [INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_INSERT_MEDIA_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ATTACH_DISK_LINK, INSTANTIATED_VM_DETACH_DISK_LINK,
          URL, INSTANTIATED_VM_ID, URL, URL, INSTANTIATED_VM_ID,
          SCSI_CONTROLLER_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_NETWORK_SECTION_LINK,
          INSTANTIATED_VM_NETWORK_SECTION_LINK, URL, INSTANTIATED_VM_ID,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID]).strip

        INSTANTIATED_VM_MODIFY_TASK_LINK = "#{URL}/api/task/16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7"

        INSTANTIATED_VM_MODIFY_TASK_RUNNING = (File.read(Test.spec_asset(
          "instantiated_vm_modify_task_running.xml")) % [VM_NAME,
          INSTANTIATED_VM_ID, URL, URL, VM_NAME, URL, INSTANTIATED_VM_ID, URL,
          URL]).strip

        INSTANTIATED_VM_MODIFY_TASK_SUCCESS = (File.read(Test.spec_asset(
          "instantiated_vm_modify_task_success.xml")) % [VM_NAME,
          INSTANTIATED_VM_ID, URL, VM_NAME, URL, INSTANTIATED_VM_ID, URL,
          URL]).strip

        INSTANTED_VM_CHANGE_TASK_LINK = "#{URL}/api/task/2eea2897-d189-4cf7-9739-758dbfd225d6"

        INSTANTED_VM_CHANGE_TASK_RUNNING = (File.read(Test.spec_asset(
          "instantiated_vm_change_task_running.xml")) % [VM1_ID,
          INSTANTED_VM_CHANGE_TASK_LINK, URL, URL, URL, URL]).strip

        INSTANTED_VM_CHANGE_TASK_SUCCESS = (File.read(Test.spec_asset(
          "instantiated_vm_change_task_success.xml")) % [VM1_ID,
          INSTANTED_VM_CHANGE_TASK_LINK, URL, URL, URL, URL]).strip

        INSTANTIATED_VM_HARDWARE_SECTION_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"

        CHANGED_VM_NEW_DISK_SIZE = 350

        RECONFIGURE_VM_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/reconfigureVm"

        RECONFIGURE_VM_REQUEST = (File.read(Test.spec_asset(
          "reconfigure_vm_request.xml")) % [CHANGED_VM_NAME, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, CHANGED_VM_DESCRIPTION, URL,
          INSTANTIATED_VM_ID, CHANGED_VM_DISK, URL, INSTANTIATED_VM_ID,
          CHANGED_VM_CPU, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          CHANGED_VM_MEMORY, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL,
          INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID, INSTANTIATED_VM_ID,
          URL, INSTANTIATED_VM_ID, URL, INSTANTIATED_VM_ID]).strip

        RECONFIGURE_VM_TASK = (File.read(Test.spec_asset(
          "reconfigure_vm_task.xml")) % [INSTANTIATED_VM_ID, URL, URL, VM1_ID,
          URL, URL]).strip

        UNDEPLOY_PARAMS = File.read(Test.spec_asset( "undeploy_params.xml")).strip

        ORG_NETWORK_RESPONSE = (File.read(Test.spec_asset(
          "org_network_response.xml")) % [ORG_NETWORK_NAME, ORG_NETWORK_ID,
          ORG_NETWORK_LINK, ORG_NETWORK_ID]).strip

        INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vapp_network_config_section_response.xml")) %
          [INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK]).strip

        INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_REQUEST = (File.read(
          Test.spec_asset("instantiated_vapp_network_config_add_network_request.xml")) %
          [INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK, VAPP_NETWORK_NAME,
          ORG_NETWORK_NAME, ORG_NETWORK_LINK]).strip

        INSTANTIATED_VAPP_NETWORK_CONFIG_REMOVE_NETWORK_REQUEST = (File.read(Test.spec_asset(
          "instantiated_vapp_network_config_remove_network_request.xml")) %
          [INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK,
          INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK]).strip

        INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_TASK_LINK = "#{URL}/api/task/23e5280c-2a91-4a8c-a136-9822ba33f34f"

        INSTANTIATED_VAPP_NETWORK_CONFIG_MODIFY_NETWORK_TASK_SUCCESS = (File.read(Test.spec_asset(
          "instantiated_vapp_network_config_modify_network_task_success.xml")) %
          [VAPP_NAME, VAPP_ID, INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_TASK_LINK,
          URL, URL, URL, ORGANIZATION, URL]).strip

        NEW_NIC_INDEX = "1"

        NEW_NIC_ADDRESSING_MODE = "POOL"

        INSTANTIATED_VM_NETWORK_SECTION_RESPONSE = (File.read(Test.spec_asset(
          "instantiated_vm_network_section_response.xml")) %
          [INSTANTIATED_VM_NETWORK_SECTION_LINK,
          INSTANTIATED_VM_NETWORK_SECTION_LINK]).strip

        MEDIA_ID  = "35aa7d6c-0794-456b-bbd1-021bb75e2af7"

        # bogus content
        MEDIA_CONTENT = "35aa7d6c-0794-456b-bbd1-021bb75e2af7"

        MEDIA_LINK = "#{URL}/api/media/#{MEDIA_ID}"

        MEDIA_DELETE_TASK_ID = "ddaa7d6c-0794-456b-bbd1-021bb75e2abc"

        MEDIA_DELETE_TASK_LINK = "#{URL}/api/task/#{EXISTING_MEDIA_DELETE_TASK_ID}"

        MEDIA_DELETE_TASK_DONE = (File.read(Test.spec_asset(
          "media_delete_task_done.xml")) % [MEDIA_DELETE_TASK_ID,
          MEDIA_DELETE_TASK_LINK, URL, MEDIA_DELETE_TASK_ID, MEDIA_LINK,
          USERNAME, URL, ORGANIZATION, URL]).strip

        MEDIA_ISO_LINK  = "#{URL}/transfer/1ff5509a-4cd8-4005-aa14-f009578651e9/file"

        MEDIA_UPLOAD_REQUEST = (File.read(Test.spec_asset(
          "media_upload_request.xml")) % [MEDIA_NAME]).strip

        MEDIA_UPLOAD_PENDING_RESPONSE = (File.read(Test.spec_asset(
          "media_upload_pending_response.xml")) % [MEDIA_NAME, MEDIA_ID,
          MEDIA_LINK, VDC_LINK, URL, MEDIA_ID, MEDIA_ISO_LINK, USERNAME,
          URL]).strip

        MEDIA_ADD_TO_CATALOG_REQUEST = (File.read(Test.spec_asset(
          "media_add_to_catalog_request.xml")) % [MEDIA_NAME, MEDIA_NAME,
          MEDIA_ID, URL, MEDIA_ID]).strip

        MEDIA_CATALOG_ITEM_ID = "a0185003-1a65-4fe4-9fe1-08e81ce26ef6"

        MEDIA_CATALOG_ITEM_DELETE_LINK = "#{URL}/api/catalogItem/#{MEDIA_CATALOG_ITEM_ID}"

        MEDIA_ADD_TO_CATALOG_RESPONSE = (File.read(Test.spec_asset(
          "media_add_to_catalog_response.xml")) % [MEDIA_NAME,
          MEDIA_CATALOG_ITEM_ID, URL, MEDIA_CATALOG_ITEM_ID, URL, URL,
          MEDIA_CATALOG_ITEM_ID, URL, MEDIA_CATALOG_ITEM_ID,
          MEDIA_CATALOG_ITEM_DELETE_LINK, MEDIA_NAME, MEDIA_LINK]).strip

        METADATA_VALUE = "test123"

        METADATA_KEY = "test_key"

        METADATA_SET_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata/#{METADATA_KEY}"

        METADATA_SET_REQUEST = (File.read(Test.spec_asset(
          "metadata_set_request.xml")) % [METADATA_VALUE]).strip

        METADATA_SET_TASK_DONE = (File.read(Test.spec_asset(
          "metadata_set_task_done.xml")) % [INSTANTIATED_VM_ID, URL, URL, URL,
          USERNAME, URL, ORGANIZATION, URL]).strip

        INDY_DISK_CREATE_REQUEST = (File.read(Test.spec_asset(
          "indy_disk_create_request.xml")) %
          [INDY_DISK_NAME, INDY_DISK_SIZE * 1024 * 1024]).strip

        INDY_DISK_CREATE_RESPONSE = (File.read(Test.spec_asset(
          "indy_disk_create_response.xml")) % [INDY_DISK_ID, URL, INDY_DISK_ID,
          URL, INDY_DISK_URL, URL, INDY_DISK_ID, URL, INDY_DISK_ID, URL,
          INDY_DISK_ID, INDY_DISK_ID, URL, URL, URL, INDY_DISK_ID, URL, URL,
          URL, URL]).strip

        INDY_DISK_CREATE_ERROR = File.read(Test.spec_asset(
          "indy_disk_create_error.xml")).strip

        INDY_DISK_RESPONSE = (File.read(Test.spec_asset(
          "indy_disk_response.xml")) % [INDY_DISK_NAME, INDY_DISK_ID,
          INDY_DISK_URL, URL, URL, INDY_DISK_ID, URL, INDY_DISK_ID, URL,
          INDY_DISK_ID, URL, INDY_DISK_ID, URL, URL]).strip

        INDY_DISK_ADDRESS_ON_PARENT = "1"

        INDY_DISK_ATTACH_REQUEST = (File.read(Test.spec_asset(
          "indy_disk_attach_request.xml")) % [INDY_DISK_URL]).strip

        INDY_DISK_ATTACH_TASK = (File.read(Test.spec_asset(
          "indy_disk_attach_task.xml")) % [URL, URL, VM_NAME, URL, VM1_ID,
          USERNAME, URL, ORGANIZATION, URL]).strip

        INDY_DISK_ATTACH_TASK_ERROR = (File.read(Test.spec_asset(
          "indy_disk_attach_task_error.xml")) % [URL, URL, VM_NAME, URL, VM1_ID,
          USERNAME, URL, ORGANIZATION, URL]).strip

        INDY_DISK_DETACH_REQUEST = (File.read(Test.spec_asset(
          "indy_disk_detach_request.xml")) % [INDY_DISK_URL]).strip

        INDY_DISK_DETACH_TASK = (File.read(Test.spec_asset(
          "indy_disk_detach_task.xml")) % [URL, URL, VM_NAME, URL, USERNAME,
          URL, ORGANIZATION, URL]).strip

        INDY_DISK_DELETE_TASK = (File.read(Test.spec_asset(
          "indy_disk_delete_task.xml")) % [INDY_DISK_ID, URL, URL,
          INDY_DISK_URL, USERNAME, URL, ORGANIZATION, URL]).strip

        EXISTING_VAPP_RESOLVER_RESPONSE = (File.read(Test.spec_asset(
          "existing_vapp_resolver_response.xml")) % [EXISTING_VAPP_URN,
          EXISTING_VAPP_URN, EXISTING_VAPP_RESOLVER_URL,
          EXISTING_VAPP_LINK]).strip

        EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_RESPONSE = (File.read(Test.spec_asset(
          "existing_vapp_template_catalog_resolver_response.xml")) %
          [EXISTING_VAPP_TEMPLATE_CATALOG_URN,
          EXISTING_VAPP_TEMPLATE_CATALOG_URN,
          EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_URL,
          EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_LINK]).strip

        VAPP_TEMPLATE_CATALOG_RESOLVER_RESPONSE = (File.read(Test.spec_asset(
          "vapp_template_catalog_resolver_response.xml")) %
          [VAPP_TEMPLATE_CATALOG_URN, VAPP_TEMPLATE_CATALOG_URN,
          VAPP_TEMPLATE_CATALOG_RESOLVER_URL,
          VAPP_TEMPLATE_CATALOG_ITEM_LINK]).strip

      end
    end
end
