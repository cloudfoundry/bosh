module VCloudSdk
  module Xml
    VCLOUD_NAMESPACE = "http://www.vmware.com/vcloud/v1.5"

    OVF = "http://schemas.dmtf.org/ovf/envelope/1"

    RASD = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/" +
           "CIM_ResourceAllocationSettingData"

    # http://blogs.vmware.com/vapp/2009/11/virtual-hardware-in-ovf-part-1.html
    HARDWARE_TYPE = {
        :CPU => "3",
        :MEMORY => "4",
        :SCSI_CONTROLLER => "6",
        :NIC => "10",
        :HARD_DISK => "17"
    }

    RASD_TYPES = {
        :RESOURCE_TYPE => "ResourceType",
        :HOST_RESOURCE => "HostResource",
        :INSTANCE_ID => "InstanceID",
        :RESOURCE_SUB_TYPE => "ResourceSubType",
        :ADDRESS_ON_PARENT => "AddressOnParent",
        :ADDRESS => "Address",
        :CONNECTION => "Connection",
        :PARENT => "Parent"
    }

    RESOURCE_SUB_TYPE = {
        :VMXNET3 => "VMXNET3"
    }

    BUS_SUB_TYPE = {
        :LSILOGIC => "lsilogic"
    }

    IMAGE_TYPES = {
        :ISO => "iso",
        :FLOPPY => "floppy"
    }

    IP_ADDRESSING_MODE = {
        :NONE => "NONE",
        :MANUAL => "MANUAL",
        :POOL => "POOL",
        :DHCP => "DHCP"
    }

    FENCE_MODES = {
        :BRIDGED => "bridged",
        :ISOLATED => "isolated",
        :NAT_ROUTED => "natRouted"
    }

    HOST_RESOURCE_ATTRIBUTE = {
        :CAPACITY => "capacity",
        :BUS_SUB_TYPE => "busSubType",
        :BUS_TYPE => "busType"
    }

    TASK_STATUS = {
        :QUEUED => "queued",
        :RUNNING => "running",
        :SUCCESS => "success",
        :ERROR => "error",
        :CANCELED => "canceled",
        :PRE_RUNNING => "pre-running",
        :ABORTED => "aborted"
    }

    MAX_DISK_ID = 15

    MEDIA_TYPE = {
        :ENTITY => "application/vnd.vmware.vcloud.entity+xml",
        :ORGANIZATION => "application/vnd.vmware.vcloud.org+xml",
        :ORGANIZATION_LIST => "application/vnd.vmware.vcloud.orgList+xml",
        :VDC => "application/vnd.vmware.vcloud.vdc+xml",
        :UPLOAD_VAPP_TEMPLATE_PARAMS =>
          "application/vnd.vmware.vcloud.uploadVAppTemplateParams+xml",
        :INSTANTIATE_OVF_PARAMS =>
          "application/vnd.vmware.vcloud.instantiateOvfParams+xml",
        :INSTANTIATE_VAPP_TEMPLATE_PARAMS =>
          "application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml",
        :CLONE_VAPP_PARAMS =>
          "application/vnd.vmware.vcloud.cloneVAppParams+xml",
        :CLONE_VAPP_TEMPLATE_PARAMS =>
          "application/vnd.vmware.vcloud.cloneVAppTemplateParams+xml",
        :CLONE_MEDIA_PARAMS =>
          "application/vnd.vmware.vcloud.cloneMediaParams+xml",
        :DEPLOY_VAPP_PARAMS =>
          "application/vnd.vmware.vcloud.deployVAppParams+xml",
        :UNDEPLOY_VAPP_PARAMS =>
          "application/vnd.vmware.vcloud.undeployVAppParams+xml",
        :UNDEPLOY_VAPP_PARAMS_EXTENDED =>
          "application/vnd.vmware.vcloud.undeployVAppParamsExtended+xml",
        :CAPTURE_VAPP_PARAMS =>
          "application/vnd.vmware.vcloud.captureVAppParams+xml",
        :COMPOSE_VAPP_PARAMS =>
          "application/vnd.vmware.vcloud.composeVAppParams+xml",
        :VAPP_TEMPLATE => "application/vnd.vmware.vcloud.vAppTemplate+xml",
        :VAPP => "application/vnd.vmware.vcloud.vApp+xml",
        :VM => "application/vnd.vmware.vcloud.vm+xml",
        :VMS => "application/vnd.vmware.vcloud.vms+xml",
        :MEDIA => "application/vnd.vmware.vcloud.media+xml",
        :VAPP_NETWORK => "application/vnd.vmware.vcloud.vAppNetwork+xml",
        :ORG_NETWORK => "application/vnd.vmware.vcloud.orgNetwork+xml",
        :NETWORK => "application/vnd.vmware.vcloud.network+xml",
        :TASK => "application/vnd.vmware.vcloud.task+xml",
        :TASKS_LIST => "application/vnd.vmware.vcloud.tasksList+xml",
        :CATALOG => "application/vnd.vmware.vcloud.catalog+xml",
        :CATALOG_ITEM => "application/vnd.vmware.vcloud.catalogItem+xml",
        :ERROR => "application/vnd.vmware.vcloud.error+xml",
        :SCREEN_TICKET => "application/vnd.vmware.vcloud.screenTicket+xml",
        :CONTROL_ACCESS => "application/vnd.vmware.vcloud.controlAccess+xml",
        :MEDIA_INSERT_EJECT_PARAMS =>
          "application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml",
        :QUESTION => "application/vnd.vmware.vcloud.vmPendingQuestion+xml",
        :ANSWER => "application/vnd.vmware.vcloud.vmPendingAnswer+xml",
        :RECOMPOSE_VAPP_PARAMS =>
          "application/vnd.vmware.vcloud.recomposeVAppParams+xml",
        :RELOCATE_VM_PARAMS =>
          "application/vnd.vmware.vcloud.relocateVmParams+xml",
        :OWNER => "application/vnd.vmware.vcloud.owner+xml",
        :REFERENCES => "application/vnd.vmware.vcloud.query.references+xml",
        :RECORDS => "application/vnd.vmware.vcloud.query.records+xml",
        :IDRECORDS => "application/vnd.vmware.vcloud.query.idrecords+xml",
        :QUERY_LIST => "application/vnd.vmware.vcloud.query.queryList+xml",
        :SESSION => "application/vnd.vmware.vcloud.session+xml",
        :SHADOW_VMS => "application/vnd.vmware.vcloud.shadowVms+xml",
        :METADATA => "application/vnd.vmware.vcloud.metadata+xml",
        :METADATA_ITEM_VALUE =>
          "application/vnd.vmware.vcloud.metadata.value+xml",
        :ENTITY_REFERENCE =>
          "application/vnd.vmware.vcloud.entity.reference+xml",
        :DISK => "application/vnd.vmware.vcloud.disk+xml",
        :DISK_CREATE_PARAMS =>
          "application/vnd.vmware.vcloud.diskCreateParams+xml",
        :DISK_ATTACH_DETACH_PARAMS =>
          "application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml",
        :VDC_STORAGE_CLASS =>
          "application/vnd.vmware.vcloud.vdcStorageClass+xml",
        :VDC_STORAGE_PROFILE =>
          "application/vnd.vmware.vcloud.vdcStorageProfile+xml",
        :ALLOCATED_NETWORK_IPS =>
          "application/vnd.vmware.vcloud.allocatedNetworkAddress+xml",
        :LEASE_SETTINGS_SECTION =>
          "application/vnd.vmware.vcloud.leaseSettingsSection+xml",
        :STARTUP_SECTION =>
          "application/vnd.vmware.vcloud.startupSection+xml",
        :NETWORK_SECTION =>
          "application/vnd.vmware.vcloud.networkSection+xml",
        :NETWORK_CONFIG_SECTION =>
          "application/vnd.vmware.vcloud.networkConfigSection+xml",
        :PRODUCT_SECTIONS =>
          "application/vnd.vmware.vcloud.productSections+xml",
        :NETWORK_CONNECTION_SECTION =>
          "application/vnd.vmware.vcloud.networkConnectionSection+xml",
        :OPERATING_SYSTEM_SECTION =>
          "application/vnd.vmware.vcloud.operatingSystemSection+xml",
        :VIRTUAL_HARDWARE_SECTION =>
          "application/vnd.vmware.vcloud.virtualHardwareSection+xml",
        :RUNTIME_INFO_SECTION =>
          "application/vnd.vmware.vcloud.runtimeInfoSection+xml",
        :GUEST_CUSTOMIZATION_SECTION =>
          "application/vnd.vmware.vcloud.guestCustomizationSection+xml",
        :CUSTOMIZATION_SECTION =>
          "application/vnd.vmware.vcloud.customizationSection+xml",
        :RASD_ITEM => "application/vnd.vmware.vcloud.rasdItem+xml",
        :RASD_ITEMS_LIST => "application/vnd.vmware.vcloud.rasdItemsList+xml",
        :OVF => "text/xml",
        :APPLICATION_XML => "application/*+xml"
    }

    ADMIN_MEDIA_TYPE = {
      :ADMIN_MEDIA_TYPE_PREFIX => "application/vnd.vmware.admin.",
      :VCLOUD => "application/vnd.vmware.admin.vcloud+xml",
      :PROVIDER_VDC => "application/vnd.vmware.admin.providervdc+xml",
      :ADMIN_VDC => "application/vnd.vmware.admin.vdc+xml",
      :VDC => "application/vnd.vmware.vcloud.vdc+xml",
      :VAPP_TEMPLATE => "application/vnd.vmware.vcloud.vAppTemplate+xml",
      :VAPP => "application/vnd.vmware.vcloud.vApp+xml",
      :VM => "application/vnd.vmware.vcloud.vm+xml",
      :MEDIA => "application/vnd.vmware.vcloud.media+xml",
      :SYSTEM_ADMIN_ORGANIZATION =>
        "application/vnd.vmware.admin.systemOrganization+xml",
      :ADMIN_ORGANIZATION => "application/vnd.vmware.admin.organization+xml",
      :ORGANIZATION => "application/vnd.vmware.vcloud.org+xml",
      :TASKS_LIST => "application/vnd.vmware.vcloud.tasksList+xml",
      :USER => "application/vnd.vmware.admin.user+xml",
      :GROUP => "application/vnd.vmware.admin.group+xml",
      :ROLE => "application/vnd.vmware.admin.role+xml",
      :RIGHT => "application/vnd.vmware.admin.right+xml",
      :ADMIN_CATALOG => "application/vnd.vmware.admin.catalog+xml",
      :CATALOG => "application/vnd.vmware.vcloud.catalog+xml",
      :ADMIN_CATALOG_ITEM => "application/vnd.vmware.admin.catalogItem+xml",
      :CATALOG_ITEM => "application/vnd.vmware.vcloud.catalogItem+xml",
      :ADMIN_NETWORK => "application/vnd.vmware.admin.network+xml",
      :NETWORK => "application/vnd.vmware.vcloud.network+xml",
      :NETWORK_POOL => "application/vnd.vmware.admin.networkPool+xml",
      :CATALOG_PUBLISH =>
        "application/vnd.vmware.admin.publishCatalogParams+xml",
      :OWNER => "application/vnd.vmware.vcloud.owner+xml",
      :ORG_SETTINGS => "application/vnd.vmware.admin.orgSettings+xml",
      :VAPP_TEMPLATE_LEASE_SETTINGS =>
        "application/vnd.vmware.admin.vAppTemplateLeaseSettings+xml",
      :VAPP_LEASE_SETTINGS =>
        "application/vnd.vmware.admin.vAppLeaseSettings+xml",
      :EMAIL_SETTINGS =>
        "application/vnd.vmware.admin.organizationEmailSettings+xml",
      :GENERAL_SETTINGS =>
        "application/vnd.vmware.admin.organizationGeneralSettings+xml",
      :ORGANIZATION_PASSWORD_POLICY_SETTINGS =>
        "application/vnd.vmware.admin.organizationPasswordPolicySettings+xml",
    }

    XML_TYPE = {
      :ADMINALLOCATEDEXTIPRECORD => "AdminAllocatedExtIpRecord",
      :ADMINCATALOG => "AdminCatalog",
      :ADMINCATALOGITEMRECORD => "AdminCatalogItemRecord",
      :ADMINCATALOGRECORD => "AdminCatalogRecord",
      :ADMINGROUPRECORD => "AdminGroupRecord",
      :ADMINMEDIARECORD => "AdminMediaRecord",
      :ADMINORG => "AdminOrg",
      :ADMINORGNETWORKRECORD => "AdminOrgNetworkRecord",
      :ADMINSHADOWVMRECORD => "AdminShadowVmRecord",
      :ADMINTASKRECORD => "AdminTaskRecord",
      :ADMINUSERRECORD => "AdminUserRecord",
      :ADMINVAPPNETWORKRECORD => "AdminVAppNetworkRecord",
      :ADMINVAPPRECORD => "AdminVAppRecord",
      :ADMINVAPPREFERENCE => "AdminVAppReference",
      :ADMINVAPPREFERENCES => "AdminVAppReferences",
      :ADMINVAPPTEMPLATERECORD => "AdminVAppTemplateRecord",
      :ADMINVDC => "AdminVdc",
      :ADMINVDCRECORD => "AdminVdcRecord",
      :ADMINVDCREFERENCE => "AdminVdcReference",
      :ADMINVDCREFERENCES => "AdminVdcReferences",
      :ADMINVMRECORD => "AdminVmRecord",
      :ALLEULASACCEPTED => "AllEULAsAccepted",
      :ALLOCATEDEXTIPRECORD => "AllocatedExtIpRecord",
      :BLOCKINGTASKRECORD => "BlockingTaskRecord",
      :BLOCKINGTASKREFERENCE => "BlockingTaskReference",
      :BLOCKINGTASKREFERENCES => "BlockingTaskReferences",
      :CAPTUREVAPPPARAMS => "CaptureVAppParams",
      :CATALOG => "Catalog",
      :CATALOGITEM => "CatalogItem",
      :CATALOGITEMRECORD => "CatalogItemRecord",
      :CATALOGITEMREFERENCE => "CatalogItemReference",
      :CATALOGITEMREFERENCES => "CatalogItemReferences",
      :CATALOGRECORD => "CatalogRecord",
      :CATALOGREFERENCE => "CatalogReference",
      :CATALOGREFERENCES => "CatalogReferences",
      :CELLRECORD => "CellRecord",
      :CLONEMEDIAPARAMS => "CloneMediaParams",
      :CLONEVAPPPARAMS => "CloneVAppParams",
      :CLONEVAPPTEMPLATEPARAMS => "CloneVAppTemplateParams",
      :COMPOSEVAPPPARAMS => "ComposeVAppParams",
      :CONTROLACCESSPARAMS => "ControlAccessParams",
      :CUSTOMIZATIONSECTION => "CustomizationSection",
      :DATASTOREPROVIDERVDCRELATIONRECORD =>
        "DatastoreProviderVdcRelationRecord",
      :DATASTORERECORD => "DatastoreRecord",
      :DATASTOREREFERENCE => "DatastoreReference",
      :DATASTOREREFERENCES => "DatastoreReferences",
      :DEPLOYVAPPPARAMS => "DeployVAppParams",
      :DHCPSERVICE => "DhcpService",
      :DVSWITCHRECORD => "DvSwitchRecord",
      :ENTITY => "Entity",
      :ERROR => "Error",
      :EVENTRECORD => "EventRecord",
      :EXTERNALNETWORK => "ExternalNetwork",
      :FILE => "File",
      :FIREWALLSERVICE => "FirewallService",
      :GENERALORGSETTINGS => "GeneralOrgSettings",
      :GROUP => "Group",
      :GROUPRECORD => "GroupRecord",
      :GROUPREFERENCE => "GroupReference",
      :GROUPREFERENCES => "GroupReferences",
      :GUESTCUSTOMIZATIONSECTION => "GuestCustomizationSection",
      :HOSTRECORD => "HostRecord",
      :HOSTREFERENCE => "HostReference",
      :HOSTREFERENCES => "HostReferences",
      :INSTANTIATEOVFPARAMS => "InstantiateOvfParams",
      :INSTANTIATEVAPPTEMPLATEPARAMS => "InstantiateVAppTemplateParams",
      :IPSECVPNLOCALPEER => "IpsecVpnLocalPeer",
      :IPSECVPNPEER => "IpsecVpnPeer",
      :IPSECVPNREMOTEPEER => "IpsecVpnRemotePeer",
      :IPSECVPNSERVICE => "IpsecVpnService",
      :IPSECVPNTHIRDPARTYPEER => "IpsecVpnThirdPartyPeer",
      :ITEM => "Item",
      :LEASESETTINGSSECTION => "LeaseSettingsSection",
      :LINK => "Link",
      :MEDIA => "Media",
      :MEDIAINSERTOREJECTPARAMS => "MediaInsertOrEjectParams",
      :MEDIARECORD => "MediaRecord",
      :MEDIAREFERENCE => "MediaReference",
      :MEDIAREFERENCES => "MediaReferences",
      :METADATA => "Metadata",
      :METADATAVALUE => "MetadataValue",
      :NATSERVICE => "NatService",
      :NETWORKASSIGNMENT => "NetworkAssignment",
      :NETWORKCONFIGSECTION => "NetworkConfigSection",
      :NETWORKCONNECTION => "NetworkConnection",
      :NETWORKCONNECTIONSECTION => "NetworkConnectionSection",
      :NETWORKPOOLRECORD => "NetworkPoolRecord",
      :NETWORKPOOLREFERENCE => "NetworkPoolReference",
      :NETWORKPOOLREFERENCES => "NetworkPoolReferences",
      :NETWORKRECORD => "NetworkRecord",
      :NETWORKREFERENCE => "NetworkReference",
      :NETWORKREFERENCES => "NetworkReferences",
      :NETWORKSERVICE => "NetworkService",
      :ORG => "Org",
      :ORGEMAILSETTINGS => "OrgEmailSettings",
      :ORGLIST => "OrgList",
      :ORGNETWORK => "OrgNetwork",
      :ORGNETWORKRECORD => "OrgNetworkRecord",
      :ORGNETWORKREFERENCE => "OrgNetworkReference",
      :ORGNETWORKREFERENCES => "OrgNetworkReferences",
      :ORGPASSWORDPOLICYSETTINGS => "OrgPasswordPolicySettings",
      :ORGRECORD => "OrgRecord",
      :ORGREFERENCE => "OrgReference",
      :ORGREFERENCES => "OrgReferences",
      :ORGSETTINGS => "OrgSettings",
      :ORGVAPPTEMPLATELEASESETTINGS => "OrgVAppTemplateLeaseSettings",
      :ORGVDCRECORD => "OrgVdcRecord",
      :ORGVDCREFERENCE => "OrgVdcReference",
      :ORGVDCREFERENCES => "OrgVdcReferences",
      :ORGVDCRESOURCEPOOLRELATIONRECORD => "OrgVdcResourcePoolRelationRecord",
      :OWNER => "Owner",
      :PORTGROUPRECORD => "PortgroupRecord",
      :PRODUCTSECTIONLIST => "ProductSectionList",
      :PROVIDERVDC => "ProviderVdc",
      :PROVIDERVDCRESOURCEPOOLRELATIONRECORD =>
        "ProviderVdcResourcePoolRelationRecord",
      :PUBLISHCATALOGPARAMS => "PublishCatalogParams",
      :QUERYLIST => "QueryList",
      :QUERYRESULTRECORDS => "QueryResultRecords",
      :RASDITEMSLIST => "RasdItemsList",
      :RECOMPOSEVAPPPARAMS => "RecomposeVAppParams",
      :RECORD => "Record",
      :REFERENCE => "Reference",
      :REFERENCES => "References",
      :RELOCATEPARAMS => "RelocateParams",
      :RESOURCEENTITY => "ResourceEntity",
      :RESOURCEPOOLRECORD => "ResourcePoolRecord",
      :RIGHT => "Right",
      :RIGHTRECORD => "RightRecord",
      :RIGHTREFERENCE => "RightReference",
      :RIGHTREFERENCES => "RightReferences",
      :ROLE => "Role",
      :ROLERECORD => "RoleRecord",
      :ROLEREFERENCE => "RoleReference",
      :ROLEREFERENCES => "RoleReferences",
      :RUNTIMEINFOSECTION => "RuntimeInfoSection",
      :SCREENTICKET => "ScreenTicket",
      :SESSION => "Session",
      :SHADOWVMREFERENCES => "ShadowVMReferences",
      :STATICROUTINGSERVICE => "StaticRoutingService",
      :STRANDEDUSERRECORD => "StrandedUserRecord",
      :TASK => "Task",
      :TASKRECORD => "TaskRecord",
      :TASKREFERENCE => "TaskReference",
      :TASKREFERENCES => "TaskReferences",
      :TASKSLIST => "TasksList",
      :UNDEPLOYVAPPPARAMS => "UndeployVAppParams",
      :UPLOADVAPPTEMPLATEPARAMS => "UploadVAppTemplateParams",
      :USER => "User",
      :USERRECORD => "UserRecord",
      :USERREFERENCE => "UserReference",
      :USERREFERENCES => "UserReferences",
      :VAPP => "VApp",
      :VAPPLEASESETTINGS => "VAppLeaseSettings",
      :VAPPNETWORK => "VAppNetwork",
      :VAPPNETWORKRECORD => "VAppNetworkRecord",
      :VAPPNETWORKREFERENCE => "VAppNetworkReference",
      :VAPPNETWORKREFERENCES => "VAppNetworkReferences",
      :VAPPORGNETWORKRELATIONRECORD => "VAppOrgNetworkRelationRecord",
      :VAPPORGNETWORKRELATIONREFERENCE => "VAppOrgNetworkRelationReference",
      :VAPPORGNETWORKRELATIONREFERENCES => "VAppOrgNetworkRelationReferences",
      :VAPPRECORD => "VAppRecord",
      :VAPPREFERENCE => "VAppReference",
      :VAPPREFERENCES => "VAppReferences",
      :VAPPTEMPLATE => "VAppTemplate",
      :VAPPTEMPLATERECORD => "VAppTemplateRecord",
      :VAPPTEMPLATEREFERENCE => "VAppTemplateReference",
      :VAPPTEMPLATEREFERENCES => "VAppTemplateReferences",
      :VCLOUD => "VCloud",
      :VDC => "Vdc",
      :VDCREFERENCES => "VdcReferences",
      :VIRTUALCENTERRECORD => "VirtualCenterRecord",
      :VIRTUALCENTERREFERENCE => "VirtualCenterReference",
      :VIRTUALCENTERREFERENCES => "VirtualCenterReferences",
      :VM => "Vm",
      :VMPENDINGQUESTION => "VmPendingQuestion",
      :VMQUESTIONANSWER => "VmQuestionAnswer",
      :VMRECORD => "VMRecord",
      :VMREFERENCE => "VMReference",
      :VMREFERENCES => "VMReferences",
      :VMWPROVIDERVDCRECORD => "VMWProviderVdcRecord",
      :VMWPROVIDERVDCREFERENCE => "VMWProviderVdcReference",
      :VMWPROVIDERVDCREFERENCES => "VMWProviderVdcReferences"
    }

    RESOURCE_ENTITY_STATUS = {
      :FAILED_CREATION => -1,
      :UNRESOLVED => 0,
      :RESOLVED => 1,
      :DEPLOYED => 2,
      :SUSPENDED => 3,
      :POWERED_ON => 4,
      :WAITING_FOR_INPUT => 5,
      :UNKNOWN => 6,
      :UNRECOGNIZED => 7,
      :POWERED_OFF => 8,
      :INCONSISTENT_STATE => 9,
      :MIXED => 10,
      :DESCRIPTOR_PENDING => 11,
      :COPYING_CONTENTS => 12,
      :DISK_CONTENTS_PENDING => 13,
      :QUARANTINED => 14,
      :QUARANTINE_EXPIRED => 15,
      :REJECTED => 16,
      :TRANSFER_TIMEOUT => 17
    }

  end
end
