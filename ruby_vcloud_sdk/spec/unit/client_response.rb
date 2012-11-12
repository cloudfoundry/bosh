module VCloudSdk
    module Test
      module Response
        vcd = VCloudSdk::Test::vcd_settings

        USERNAME = vcd['user']
        ORGANIZATION = vcd['entities']['organization']
        OVDC = vcd['entities']['virtual_datacenter']
        VAPP_CATALOG_NAME = vcd['entities']['vapp_catalog']
        CATALOG_ID = "cfab326c-ab71-445c-bc0b-abf15239de8b"
        VDC_ID = "a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"
        URL = vcd['url']
        URLN = URI.parse(vcd['url']).normalize.to_s
        VAPP_TEMPLATE_NAME = "test_vapp_template"
        EXISTING_VAPP_TEMPLATE_NAME  = "existing_template"
        EXISTING_VAPP_TEMPLATE_ID = "085f0844-9feb-43bd-b1df-3260218f5cb6"
        EXISTING_VAPP_NAME  = "existing_vapp"
        EXISTING_VAPP_ID = "085f0844-9feb-43bd-b1df-3260218f5cb2"
        EXISTING_VAPP_URN = "urn:vcloud:vapp:085f0844-9feb-43bd-b1df-3260218f5cb2"
        EXISTING_VAPP_RESOLVER_URL = "#{URL}/api/entity/#{EXISTING_VAPP_URN}"
        EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID = "521f9fc3-410f-433c-b877-1d072478c3c5"
        INSTANTIATED_VM_ID = '048e8cd8-adc8-49c6-80ee-a430ecf8f246'
        CPU = '2'
        MEMORY = '128'
        VM_NAME = 'vm1'
        VAPP_TEMPLATE_VM_URL = "#{URL}/api/vAppTemplate/vm-49acc996-0ee4-4b36-a5b5-822f3042e26c"
        CHANGED_VM_NAME = 'changed_vm1'
        CHANGED_VM_DESCRIPTION = 'changed_description'
        CHANGED_VM_CPU = '3'
        CHANGED_VM_MEMORY = '712'
        CHANGED_VM_DISK = '3072'
        MEDIA_NAME = 'test_media'

        EXISTING_MEDIA_NAME = 'existing_test_media'
        EXISTING_MEDIA_ID = 'abcf0844-9feb-43bd-b1df-3262218f5cb2'
        EXISTING_MEDIA_CATALOG_ID = 'cacef844-9feb-43bd-b1df-3262218f5cb2'

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


        SESSION = <<-session.strip()
        <?xml version="1.0" encoding="UTF-8"?>
        <Session xmlns="http://www.vmware.com/vcloud/v1.5" user="#{USERNAME}" org="#{ORGANIZATION}" type="application/vnd.vmware.vcloud.session+xml" href="#{URL}/api/session/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://localhost/api/v1.5/schema/master.xsd">
            <Link rel="down" type="application/vnd.vmware.vcloud.orgList+xml" href="#{URL}/api/org/"/>
            <Link rel="down" type="application/vnd.vmware.admin.vcloud+xml" href="#{URL}/api/admin/"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.query.queryList+xml" href="#{URL}/api/query"/>
            <Link rel="entityResolver" type="application/vnd.vmware.vcloud.entity+xml" href="#{URL}/api/entity/"/>
        </Session>
        session

        ADMIN_VCLOUD_LINK = "#{URL}/api/admin/"

        VCLOUD_RESPONSE = <<-vcloud_response.strip()
        <VCloud xmlns="http://www.vmware.com/vcloud/v1.5" name="VMware vCloud Director" type="application/vnd.vmware.admin.vcloud+xml" href="#{URL}/api/admin/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Description>0.0.1.123456 Fri Jan 08 12:15:16 PST 2010</Description>
            <OrganizationReferences>
                <OrganizationReference type="application/vnd.vmware.admin.organization+xml" name="#{ORGANIZATION}" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            </OrganizationReferences>
            <RightReferences>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Create / Reconfigure" href="#{URL}/api/admin/right/11"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Delete" href="#{URL}/api/admin/right/12"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Edit Properties" href="#{URL}/api/admin/right/13"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Power Operations" href="#{URL}/api/admin/right/18"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Sharing" href="#{URL}/api/admin/right/20"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Copy" href="#{URL}/api/admin/right/21"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Use Console" href="#{URL}/api/admin/right/22"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Change Owner" href="#{URL}/api/admin/right/24"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Edit VM Properties" href="#{URL}/api/admin/right/31"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Edit VM Memory" href="#{URL}/api/admin/right/32"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Edit VM CPU" href="#{URL}/api/admin/right/33"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Edit VM Network" href="#{URL}/api/admin/right/34"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Edit VM Hard Disk" href="#{URL}/api/admin/right/35"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp: Manage VM Password Settings" href="#{URL}/api/admin/right/36"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: Create / Delete a Catalog" href="#{URL}/api/admin/right/71"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: Edit Properties" href="#{URL}/api/admin/right/73"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: Add vApp from My Cloud" href="#{URL}/api/admin/right/74"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: Publish" href="#{URL}/api/admin/right/76"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: Sharing" href="#{URL}/api/admin/right/77"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: View Private and Shared Catalogs" href="#{URL}/api/admin/right/78"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: View Published Catalogs" href="#{URL}/api/admin/right/79"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Catalog: Change Owner" href="#{URL}/api/admin/right/80"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp Template / Media: Edit" href="#{URL}/api/admin/right/102"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp Template / Media: Create / Upload" href="#{URL}/api/admin/right/103"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp Template: Download" href="#{URL}/api/admin/right/104"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp Template / Media: Copy" href="#{URL}/api/admin/right/105"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp Template / Media: View" href="#{URL}/api/admin/right/106"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="vApp Template: Checkout" href="#{URL}/api/admin/right/107"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization: Edit Properties" href="#{URL}/api/admin/right/201"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization: Edit SMTP Settings" href="#{URL}/api/admin/right/202"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization: Edit Quotas Policy" href="#{URL}/api/admin/right/203"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization: View" href="#{URL}/api/admin/right/204"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization Network: Edit Properties" href="#{URL}/api/admin/right/207"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization Network: View" href="#{URL}/api/admin/right/208"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization: Edit Leases Policy" href="#{URL}/api/admin/right/209"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization: Edit Password Policy" href="#{URL}/api/admin/right/210"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Organization vDC: View" href="#{URL}/api/admin/right/254"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="Group / User: View" href="#{URL}/api/admin/right/304"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="General: Send Notification" href="#{URL}/api/admin/right/382"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="General: Administrator Control" href="#{URL}/api/admin/right/383"/>
                <RightReference type="application/vnd.vmware.admin.right+xml" name="General: Administrator View" href="#{URL}/api/admin/right/384"/>
            </RightReferences>
            <RoleReferences>
                <RoleReference type="application/vnd.vmware.admin.role+xml" name="Organization Administrator" href="#{URL}/api/admin/role/a08a8798-7d9b-34d6-8dad-48c7182c5f66"/>
                <RoleReference type="application/vnd.vmware.admin.role+xml" name="Catalog Author" href="#{URL}/api/admin/role/9de271ec-be55-31e8-8d56-2a097e4e3856"/>
                <RoleReference type="application/vnd.vmware.admin.role+xml" name="vApp Author" href="#{URL}/api/admin/role/1bf4457f-a253-3cf1-b163-f319f1a31802"/>
                <RoleReference type="application/vnd.vmware.admin.role+xml" name="vApp User" href="#{URL}/api/admin/role/ff1e0c91-1288-3664-82b7-a6fa303af4d1"/>
                <RoleReference type="application/vnd.vmware.admin.role+xml" name="Console Access Only" href="#{URL}/api/admin/role/ae910740-cbde-34ae-9d84-ef5c53880afe"/>
            </RoleReferences>
        </VCloud>
        vcloud_response

        ADMIN_ORG_LINK = "#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"

        ADMIN_ORG_RESPONSE = <<-admin_org_response.strip()
        <AdminOrg xmlns="http://www.vmware.com/vcloud/v1.5" name="#{ORGANIZATION}" id="urn:vcloud:org:b689c06e-1de0-4fd1-a5a3-050c479546ac" type="application/vnd.vmware.admin.organization+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="down" type="application/vnd.vmware.vcloud.tasksList+xml" href="#{URL}/api/tasksList/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/metadata"/>
            <Link rel="add" type="application/vnd.vmware.admin.catalog+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/catalogs"/>
            <Link rel="add" type="application/vnd.vmware.admin.user+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/users"/>
            <Link rel="add" type="application/vnd.vmware.admin.group+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/groups"/>
            <Link rel="add" type="application/vnd.vmware.admin.orgNetwork+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/networks"/>
            <Link rel="edit" type="application/vnd.vmware.admin.organization+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Link rel="remove" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Link rel="alternate" type="application/vnd.vmware.vcloud.org+xml" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Description/>
            <FullName>#{ORGANIZATION}</FullName>
            <IsEnabled>true</IsEnabled>
            <Settings type="application/vnd.vmware.admin.orgSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings">
                <Link rel="down" type="application/vnd.vmware.admin.vAppTemplateLeaseSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/vAppTemplateLeaseSettings"/>
                <Link rel="down" type="application/vnd.vmware.admin.organizationEmailSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/email"/>
                <Link rel="down" type="application/vnd.vmware.admin.vAppLeaseSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/vAppLeaseSettings"/>
                <Link rel="down" type="application/vnd.vmware.admin.organizationPasswordPolicySettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/passwordPolicy"/>
                <Link rel="down" type="application/vnd.vmware.admin.organizationGeneralSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/general"/>
                <Link rel="down" type="application/vnd.vmware.admin.organizationLdapSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/ldap"/>
                <Link rel="edit" type="application/vnd.vmware.admin.orgSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings"/>
                <OrgGeneralSettings type="application/vnd.vmware.admin.organizationGeneralSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/general">
                    <Link rel="edit" type="application/vnd.vmware.admin.organizationGeneralSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/general"/>
                    <CanPublishCatalogs>false</CanPublishCatalogs>
                    <DeployedVMQuota>0</DeployedVMQuota>
                    <StoredVmQuota>0</StoredVmQuota>
                    <UseServerBootSequence>false</UseServerBootSequence>
                    <DelayAfterPowerOnSeconds>0</DelayAfterPowerOnSeconds>
                </OrgGeneralSettings>
                <VAppLeaseSettings type="application/vnd.vmware.admin.vAppLeaseSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/vAppLeaseSettings">
                    <Link rel="edit" type="application/vnd.vmware.admin.vAppLeaseSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/vAppLeaseSettings"/>
                    <DeleteOnStorageLeaseExpiration>false</DeleteOnStorageLeaseExpiration>
                    <DeploymentLeaseSeconds>604800</DeploymentLeaseSeconds>
                    <StorageLeaseSeconds>2592000</StorageLeaseSeconds>
                </VAppLeaseSettings>
                <VAppTemplateLeaseSettings type="application/vnd.vmware.admin.vAppTemplateLeaseSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/vAppTemplateLeaseSettings">
                    <Link rel="edit" type="application/vnd.vmware.admin.vAppTemplateLeaseSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/vAppTemplateLeaseSettings"/>
                    <DeleteOnStorageLeaseExpiration>false</DeleteOnStorageLeaseExpiration>
                    <StorageLeaseSeconds>7776000</StorageLeaseSeconds>
                </VAppTemplateLeaseSettings>
                <OrgLdapSettings type="application/vnd.vmware.admin.organizationLdapSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/ldap">
                    <OrgLdapMode>NONE</OrgLdapMode>
                </OrgLdapSettings>
                <OrgEmailSettings type="application/vnd.vmware.admin.organizationEmailSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/email">
                    <Link rel="edit" type="application/vnd.vmware.admin.organizationEmailSettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/email"/>
                    <IsDefaultSmtpServer>true</IsDefaultSmtpServer>
                    <IsDefaultOrgEmail>true</IsDefaultOrgEmail>
                    <FromEmailAddress/>
                    <DefaultSubjectPrefix/>
                    <IsAlertEmailToAllAdmins>true</IsAlertEmailToAllAdmins>
                    <SmtpServerSettings>
                        <IsUseAuthentication>false</IsUseAuthentication>
                        <Host/>
                        <Username/>
                    </SmtpServerSettings>
                </OrgEmailSettings>
                <OrgPasswordPolicySettings type="application/vnd.vmware.admin.organizationPasswordPolicySettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/passwordPolicy">
                    <Link rel="edit" type="application/vnd.vmware.admin.organizationPasswordPolicySettings+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac/settings/passwordPolicy"/>
                    <AccountLockoutEnabled>false</AccountLockoutEnabled>
                    <InvalidLoginsBeforeLockout>5</InvalidLoginsBeforeLockout>
                    <AccountLockoutIntervalMinutes>10</AccountLockoutIntervalMinutes>
                </OrgPasswordPolicySettings>
            </Settings>
            <Users>
                <UserReference type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Users>
            <Groups/>
            <Catalogs>
                <CatalogReference type="application/vnd.vmware.admin.catalog+xml" name="#{VAPP_CATALOG_NAME}" href="#{URL}/api/admin/catalog/#{CATALOG_ID}"/>
            </Catalogs>
            <Vdcs>
                <Vdc type="application/vnd.vmware.vcloud.vdc+xml" name="#{OVDC}" href="#{URL}/api/vdc/#{VDC_ID}"/>
            </Vdcs>
            <Networks/>
        </AdminOrg>
        admin_org_response

        ORG_NETWORK_LINK = "#{URL}/api/network/#{ORG_NETWORK_ID}"

        VDC_LINK = "#{URL}/api/vdc/#{VDC_ID}"

        MEDIA_UPLOAD_LINK  = "#{URL}/api/vdc/#{VDC_ID}/media"

        VDC_INDY_DISKS_LINK = "#{URL}/api/vdc/#{VDC_ID}/disk"

        VDC_RESPONSE = <<-vdc_response.strip()
        <Vdc xmlns="http://www.vmware.com/vcloud/v1.5" status="1" name="#{OVDC}" id="urn:vcloud:vdc:#{VDC_ID}" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.org+xml" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vdc/#{VDC_ID}/metadata"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.uploadVAppTemplateParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/uploadVAppTemplate"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.media+xml" href="#{MEDIA_UPLOAD_LINK}"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/instantiateVAppTemplate"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.cloneVAppParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/cloneVApp"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.cloneVAppTemplateParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/cloneVAppTemplate"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.cloneMediaParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/cloneMedia"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.captureVAppParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/captureVApp"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.composeVAppParams+xml" href="#{URL}/api/vdc/#{VDC_ID}/action/composeVApp"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.diskCreateParams+xml" href="#{VDC_INDY_DISKS_LINK}"/>
            <Description/>
            <AllocationModel>AllocationVApp</AllocationModel>
            <StorageCapacity>
                <Units>MB</Units>
                <Allocated>0</Allocated>
                <Limit>0</Limit>
                <Used>4800</Used>
                <Overhead>0</Overhead>
            </StorageCapacity>
            <ComputeCapacity>
                <Cpu>
                    <Units>MHz</Units>
                    <Allocated>0</Allocated>
                    <Limit>0</Limit>
                    <Used>0</Used>
                    <Overhead>0</Overhead>
                </Cpu>
                <Memory>
                    <Units>MB</Units>
                    <Allocated>0</Allocated>
                    <Limit>0</Limit>
                    <Used>0</Used>
                    <Overhead>0</Overhead>
                </Memory>
            </ComputeCapacity>
            <ResourceEntities>
                <ResourceEntity type="application/vnd.vmware.vcloud.vApp+xml" name="#{EXISTING_VAPP_NAME}" href="#{URL}/api/vApp/vapp-#{EXISTING_VAPP_ID}"/>
                <ResourceEntity type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="#{EXISTING_VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"/>
                <ResourceEntity type="application/vnd.vmware.vcloud.media+xml" name="#{EXISTING_MEDIA_NAME}" href="#{URL}/api/vApp/vapp-#{EXISTING_MEDIA_ID}"/>
                <ResourceEntity type="application/vnd.vmware.vcloud.disk+xml" name="#{INDY_DISK_NAME}" href="#{INDY_DISK_URL}"/>
            </ResourceEntities>
             <AvailableNetworks>
                <Network type="application/vnd.vmware.vcloud.network+xml" name="#{ORG_NETWORK_NAME}" href="#{ORG_NETWORK_LINK}"/>
            </AvailableNetworks>
            <Capabilities>
                <SupportedHardwareVersions>
                    <SupportedHardwareVersion>vmx-04</SupportedHardwareVersion>
                    <SupportedHardwareVersion>vmx-07</SupportedHardwareVersion>
                </SupportedHardwareVersions>
            </Capabilities>
            <NicQuota>0</NicQuota>
            <NetworkQuota>1024</NetworkQuota>
            <VmQuota>100</VmQuota>
            <IsEnabled>true</IsEnabled>
        </Vdc>
        vdc_response

        VDC_VAPP_UPLOAD_LINK = "#{URL}/api/vdc/#{VDC_ID}/action/uploadVAppTemplate"


        VAPP_TEMPLATE_UPLOAD_REQUEST = <<-vapp_template_upload_request.strip()
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <ns7:UploadVAppTemplateParams xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns2="http://www.vmware.com/vcloud/v1" xmlns:ns3="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns4="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns5="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:ns6="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" xmlns:ns8="http://schemas.dmtf.org/ovf/environment/1" xmlns:ns9="http://www.vmware.com/vcloud/extension/v1.5" xmlns:ns10="http://www.vmware.com/vcloud/versions" transferFormat="" manifestRequired="false" name="#{VAPP_TEMPLATE_NAME}">
          <ns7:Description/>
        </ns7:UploadVAppTemplateParams>
        vapp_template_upload_request

        VAPP_TEMPLATE_UPLOAD_OVF_WAITING_RESPONSE = <<-vapp_template_upload_response.strip()
        <?xml version="1.0" encoding="UTF-8"?>
        <VAppTemplate xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" ovfDescriptorUploaded="false" goldMaster="false" status="0" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:c032c1a3-21a2-4ac2-8e98-0cc29229e10c" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
            <Link rel="remove" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c"/>
            <Description/>
            <Files>
                <File size="-1" bytesTransferred="0" name="descriptor.ovf">
                    <Link rel="upload:default" href="#{URL}/transfer/22467867-7ada-4a55-a9cb-e05aa30a4f96/descriptor.ovf"/>
                </File>
            </Files>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Owner>
            <Children/>
            <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c/leaseSettingsSection/" ovf:required="false">
                <ovf:Info>Lease settings section</ovf:Info>
                <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c/leaseSettingsSection/"/>
                <StorageLeaseInSeconds>7776000</StorageLeaseInSeconds>
                <StorageLeaseExpiration>2011-11-03T13:39:00.977-07:00</StorageLeaseExpiration>
            </LeaseSettingsSection>
            <CustomizationSection type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c/customizationSection/" ovf:required="false">
                <ovf:Info>VApp template customization section</ovf:Info>
                <CustomizeOnInstantiate>false</CustomizeOnInstantiate>
            </CustomizationSection>
        </VAppTemplate>
        vapp_template_upload_response

        VAPP_TEMPLATE_LINK = "#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c"

        VAPP_TEMPLATE_UPLOAD_OVF_LINK = "#{URL}/transfer/22467867-7ada-4a55-a9cb-e05aa30a4f96/descriptor.ovf"

        VAPP_TEMPLATE_NO_DISKS_RESPONSE = <<-vapp_template_no_disk_response.strip()
        <VAppTemplate xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" ovfDescriptorUploaded="true" goldMaster="false" status="0" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:61a7300c-fedd-4f0a-804b-93f16ccf49f2" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
            <Link rel="remove" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c"/>
            <Description/>
            <Files>
                <File size="120903732" bytesTransferred="0" name="haoUnOS2VMs-disk1.vmdk">
                    <Link rel="upload:default" href="#{URL}/transfer/62137697-8d51-4df6-9689-0b7f84ccc096/haoUnOS2VMs-disk1.vmdk"/>
                </File>
                <File size="10964" bytesTransferred="10964" name="descriptor.ovf">
                    <Link rel="upload:default" href="#{URL}/transfer/62137697-8d51-4df6-9689-0b7f84ccc096/descriptor.ovf"/>
                </File>
            </Files>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Owner>
            <Children/>
            <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c/leaseSettingsSection/" ovf:required="false">
                <ovf:Info>Lease settings section</ovf:Info>
                <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c/leaseSettingsSection/"/>
                <StorageLeaseInSeconds>7776000</StorageLeaseInSeconds>
                <StorageLeaseExpiration>2011-11-03T18:29:28.633-07:00</StorageLeaseExpiration>
            </LeaseSettingsSection>
            <CustomizationSection type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-c032c1a3-21a2-4ac2-8e98-0cc29229e10c/customizationSection/" ovf:required="false">
                <ovf:Info>VApp template customization section</ovf:Info>
                <CustomizeOnInstantiate>true</CustomizeOnInstantiate>
            </CustomizationSection>
        </VAppTemplate>
        vapp_template_no_disk_response

        VAPP_TEMPLATE_DISK_UPLOAD_1 = "#{URL}/transfer/62137697-8d51-4df6-9689-0b7f84ccc096/haoUnOS2VMs-disk1.vmdk"

        VAPP_TEMPLATE_UPLOAD_COMPLETE = <<-vapp_template_upload_complete.strip()
        <VAppTemplate xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" ovfDescriptorUploaded="true" goldMaster="false" status="0" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
            <Link rel="remove" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
            <Description/>
            <Tasks>
                <Task status="success" startTime="2011-08-08T11:13:07.757-07:00" operationName="vdcUploadOvfContents" operation="Finalizing upload of Virtual Application Template #{VAPP_TEMPLATE_NAME}(#{VAPP_ID})" expiryTime="2011-11-06T11:13:07.757-08:00" name="task" id="urn:vcloud:task:91bd4b57-598e-4753-8274-1172c7195468" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/91bd4b57-598e-4753-8274-1172c7195468">
                    <Link rel="task:cancel" href="#{URL}/api/task/91bd4b57-598e-4753-8274-1172c7195468/action/cancel"/>
                    <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
                    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
                    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{USERNAME}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
                    <Progress>1</Progress>
                </Task>
            </Tasks>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Owner>
            <Children/>
            <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
                <ovf:Info>Lease settings section</ovf:Info>
                <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/leaseSettingsSection/"/>
                <StorageLeaseInSeconds>7776000</StorageLeaseInSeconds>
                <StorageLeaseExpiration>2011-11-06T10:12:46.547-08:00</StorageLeaseExpiration>
            </LeaseSettingsSection>
            <CustomizationSection type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/customizationSection/" ovf:required="false">
                <ovf:Info>VApp template customization section</ovf:Info>
                <CustomizeOnInstantiate>true</CustomizeOnInstantiate>
            </CustomizationSection>
        </VAppTemplate>
        vapp_template_upload_complete

        VAPP_TEMPLATE_UPLOAD_FAILED = <<-vapp_template_upload_failed.strip()
        <VAppTemplate xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" ovfDescriptorUploaded="true" goldMaster="false" status="0" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
            <Link rel="remove" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
            <Description/>
            <Tasks>
                <Task status="error" startTime="2011-08-08T11:13:07.757-07:00" operationName="vdcUploadOvfContents" operation="Finalizing upload of Virtual Application Template #{VAPP_TEMPLATE_NAME}(#{VAPP_ID})" expiryTime="2011-11-06T11:13:07.757-08:00" name="task" id="urn:vcloud:task:91bd4b57-598e-4753-8274-1172c7195468" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/91bd4b57-598e-4753-8274-1172c7195468">
                    <Link rel="task:cancel" href="#{URL}/api/task/91bd4b57-598e-4753-8274-1172c7195468/action/cancel"/>
                    <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
                    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
                    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{USERNAME}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
                    <Progress>1</Progress>
                </Task>
            </Tasks>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Owner>
            <Children/>
            <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
                <ovf:Info>Lease settings section</ovf:Info>
                <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/leaseSettingsSection/"/>
                <StorageLeaseInSeconds>7776000</StorageLeaseInSeconds>
                <StorageLeaseExpiration>2011-11-06T10:12:46.547-08:00</StorageLeaseExpiration>
            </LeaseSettingsSection>
            <CustomizationSection type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/customizationSection/" ovf:required="false">
                <ovf:Info>VApp template customization section</ovf:Info>
                <CustomizeOnInstantiate>true</CustomizeOnInstantiate>
            </CustomizationSection>
        </VAppTemplate>
        vapp_template_upload_failed

        CATALOG_LINK = "#{URL}/api/admin/catalog/#{CATALOG_ID}"

        CATALOG_ADD_ITEM_LINK = "#{URL}/api/catalog/#{CATALOG_ID}/catalogItems"

        EXISTING_MEDIA_LINK = "#{URL}/api/media/#{EXISTING_MEDIA_ID}"

        EXISTING_MEDIA_BUSY_RESPONSE = <<-HEREDOC.strip()
        <Media xmlns="http://www.vmware.com/vcloud/v1.5" size="833536" imageType="iso" status="0" name="#{EXISTING_MEDIA_NAME}" id="urn:vcloud:media:#{EXISTING_MEDIA_ID}" type="application/vnd.vmware.vcloud.media+xml" href="#{EXISTING_MEDIA_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"/>
            <Tasks>
                <Task status="running" startTime="2011-09-22T13:12:25.343-07:00" operationName="vdcUploadMedia" operation="Finalizing upload of Media File #{EXISTING_MEDIA_NAME}(#{EXISTING_MEDIA_ID})" expiryTime="2011-12-21T13:12:25.343-08:00" name="task" id="urn:vcloud:task:025615cd-a591-4dec-89dc-331b322a3a75" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/025615cd-a591-4dec-89dc-331b322a3a75">
                    <Link rel="task:cancel" href="#{URL}/api/task/025615cd-a591-4dec-89dc-331b322a3a75/action/cancel"/>
                    <Owner type="application/vnd.vmware.vcloud.media+xml" name="#{EXISTING_MEDIA_NAME}" href="#{URL}/api/media/#{EXISTING_MEDIA_ID}"/>
                    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
                    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
                </Task>
            </Tasks>
            <Files>
                <File size="833536" bytesTransferred="833536" name="file">
                    <Link rel="upload:default" href="#{URL}/transfer/2aebe7a1-e297-439d-83ac-dc66db6fc3ff/file"/>
                </File>
            </Files>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Owner>
        </Media>
        HEREDOC

        EXISTING_MEDIA_DONE_RESPONSE = <<-HEREDOC.strip()
        <Media xmlns="http://www.vmware.com/vcloud/v1.5" size="833536" imageType="iso" status="1" name="#{EXISTING_MEDIA_NAME}" id="urn:vcloud:media:#{EXISTING_MEDIA_ID}" type="application/vnd.vmware.vcloud.media+xml" href="#{EXISTING_MEDIA_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"/>
            <Link rel="catalogItem" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/a0185003-1a65-4fe4-9fe1-08e81ce26ef6"/>
            <Link rel="remove" href="#{EXISTING_MEDIA_LINK}"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.media+xml" href="#{URL}/api/media/#{EXISTING_MEDIA_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/media/#{EXISTING_MEDIA_ID}/owner"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/media/#{EXISTING_MEDIA_ID}/metadata"/>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            </Owner>
        </Media>
        HEREDOC

        EXISTING_MEDIA_CATALOG_ITEM_LINK = "#{URL}/api/catalogItem/#{EXISTING_MEDIA_CATALOG_ID}"

        EXISTING_MEDIA_CATALOG_ITEM = <<-HEREDOC.strip()
        <CatalogItem xmlns="http://www.vmware.com/vcloud/v1.5" name="#{EXISTING_MEDIA_NAME}" id="urn:vcloud:catalogitem:#{EXISTING_MEDIA_CATALOG_ID}" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{EXISTING_MEDIA_CATALOG_ITEM_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.catalog+xml" href="#{URL}/api/catalog/cfab326c-ab71-445c-bc0b-abf15239de8b"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/catalogItem/#{EXISTING_MEDIA_CATALOG_ID}/metadata"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/#{EXISTING_MEDIA_CATALOG_ID}"/>
            <Link rel="remove" href="#{URL}/api/catalogItem/#{EXISTING_MEDIA_CATALOG_ID}"/>
            <Description/>
            <Entity type="application/vnd.vmware.vcloud.media+xml" name="#{EXISTING_MEDIA_NAME}" href="#{EXISTING_MEDIA_LINK}"/>
        </CatalogItem>
        HEREDOC

        EXISTING_MEDIA_DELETE_TASK_ID = "e0491c4a-d9e9-4b86-8c46-2d7736b8f82a"

        EXISTING_MEDIA_DELETE_TASK_LINK = "#{URL}/api/task/#{EXISTING_MEDIA_DELETE_TASK_ID}"

        EXISTING_MEDIA_DELETE_TASK_DONE = <<-HEREDOC.strip()
        <Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-22T13:12:32.551-07:00" operationName="vdcDeleteMedia" operation="Deleting Media File (4ed2b53a-dbdd-4761-8036-fa67920749c5)" expiryTime="2011-12-21T13:12:32.551-08:00" name="task" id="urn:vcloud:task:#{EXISTING_MEDIA_DELETE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{EXISTING_MEDIA_DELETE_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
            <Link rel="task:cancel" href="#{URL}/api/task/#{EXISTING_MEDIA_DELETE_TASK_ID}/action/cancel"/>
            <Owner type="application/vnd.vmware.vcloud.media+xml" name="" href="#{EXISTING_MEDIA_LINK}"/>
            <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
        </Task>
        HEREDOC

        CATALOG_RESPONSE = <<-catalog_response.strip()
        <?xml version="1.0" encoding="UTF-8"?>
        <AdminCatalog xmlns="http://www.vmware.com/vcloud/v1.5" name="#{VAPP_CATALOG_NAME}" id="urn:vcloud:catalog:#{CATALOG_ID}" type="application/vnd.vmware.admin.catalog+xml" href="#{URL}/api/admin/catalog/#{CATALOG_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.admin.organization+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Link rel="alternate" type="application/vnd.vmware.vcloud.catalog+xml" href="#{URL}/api/catalog/#{CATALOG_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/admin/catalog/#{CATALOG_ID}/owner"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{CATALOG_ADD_ITEM_LINK}"/>
            <Link rel="edit" type="application/vnd.vmware.admin.catalog+xml" href="#{URL}/api/admin/catalog/#{CATALOG_ID}"/>
            <Link rel="remove" href="#{URL}/api/admin/catalog/#{CATALOG_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/catalog/#{CATALOG_ID}/metadata"/>
            <Description/>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="system" href="#{URL}/api/admin/user/b95dbfb2-c864-4263-ac02-149a093939c0"/>
            </Owner>
            <CatalogItems>
                <CatalogItem type="application/vnd.vmware.vcloud.catalogItem+xml" name="#{EXISTING_VAPP_TEMPLATE_NAME}" href="#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"/>
                <CatalogItem type="application/vnd.vmware.vcloud.catalogItem+xml" name="#{EXISTING_MEDIA_NAME}" href="#{EXISTING_MEDIA_CATALOG_ITEM_LINK}">
            </CatalogItems>
            <IsPublished>false</IsPublished>
        </AdminCatalog>
        catalog_response


        CATALOG_ADD_VAPP_REQUEST = <<-catalog_add_vapp_request.strip()
        <ns7:CatalogItem xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns2="http://www.vmware.com/vcloud/v1" xmlns:ns3="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns4="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns5="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:ns6="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" xmlns:ns8="http://schemas.dmtf.org/ovf/environment/1" xmlns:ns9="http://www.vmware.com/vcloud/extension/v1.5" xmlns:ns10="http://www.vmware.com/vcloud/versions" name="#{VAPP_TEMPLATE_NAME}" id="" type="" href="">
          <ns7:Description/>
          <ns7:Tasks/>
          <ns7:Entity name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:#{VAPP_ID}" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml"/>
        </ns7:CatalogItem>
        catalog_add_vapp_request

        CATALOG_ADD_ITEM_RESPONSE = <<-catalog_add_item_response.strip()
        <CatalogItem xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:catalogitem:39a8f899-0f8e-40c4-ac68-66b2688833bc" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.catalog+xml" href="#{URL}/api/catalog/#{CATALOG_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc/metadata"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"/>
            <Link rel="remove" href="#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"/>
            <Description/>
            <Entity name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml"/>
        </CatalogItem>
        catalog_add_item_response

        CATALOG_ITEM_ADDED_RESPONSE = <<-catalog_item_added_response.strip()
        <?xml version="1.0" encoding="UTF-8"?>
        <AdminCatalog xmlns="http://www.vmware.com/vcloud/v1.5" name="#{VAPP_CATALOG_NAME}" id="urn:vcloud:catalog:#{CATALOG_ID}" type="application/vnd.vmware.admin.catalog+xml" href="#{URL}/api/admin/catalog/#{CATALOG_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.admin.organization+xml" href="#{URL}/api/admin/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Link rel="alternate" type="application/vnd.vmware.vcloud.catalog+xml" href="#{URL}/api/catalog/#{CATALOG_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/admin/catalog/#{CATALOG_ID}/owner"/>
            <Link rel="add" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalog/#{CATALOG_ID}/catalogItems"/>
            <Link rel="edit" type="application/vnd.vmware.admin.catalog+xml" href="#{URL}/api/admin/catalog/#{CATALOG_ID}"/>
            <Link rel="remove" href="#{URL}/api/admin/catalog/#{CATALOG_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/catalog/#{CATALOG_ID}/metadata"/>
            <Description/>
            <Owner type="application/vnd.vmware.vcloud.owner+xml">
                <User type="application/vnd.vmware.admin.user+xml" name="system" href="#{URL}/api/admin/user/b95dbfb2-c864-4263-ac02-149a093939c0"/>
            </Owner>
            <CatalogItems>
                <CatalogItem type="application/vnd.vmware.vcloud.catalogItem+xml" name="#{EXISTING_VAPP_TEMPLATE_NAME}" href="#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"/>
                <CatalogItem type="application/vnd.vmware.vcloud.catalogItem+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"/>
            </CatalogItems>
            <IsPublished>false</IsPublished>
        </AdminCatalog>
        catalog_item_added_response

        CATALOG_ITEM_VAPP_LINK = "#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"

        FINALIZE_UPLOAD_TASK_ID = "91bd4b57-598e-4753-8274-1172c7195468"

        FINALIZE_UPLOAD_TASK_LINK = "#{URL}/api/task/#{FINALIZE_UPLOAD_TASK_ID}"

        FINALIZE_UPLOAD_TASK_RESPONSE = <<-finalize_upload_task_response.strip()
        <Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-08-18T13:27:38.407-07:00" operationName="vdcUploadOvfContents" operation="Finalizing upload of Virtual Application Template #{VAPP_TEMPLATE_NAME}(#{VAPP_ID})" expiryTime="2011-11-16T13:27:38.407-08:00" name="task" id="urn:vcloud:task:#{FINALIZE_UPLOAD_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{FINALIZE_UPLOAD_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
          <Link rel="task:cancel" href="#{URL}/api/task/#{FINALIZE_UPLOAD_TASK_ID}/action/cancel"/>
          <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
          <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
          <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
          <Progress>50</Progress>
        </Task>
        finalize_upload_task_response

        FINALIZE_UPLOAD_TASK_DONE_RESPONSE = <<-finalize_upload_task_done_response.strip()
        <Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-08-18T13:27:38.407-07:00" operationName="vdcUploadOvfContents" operation="Finalizing upload of Virtual Application Template #{VAPP_TEMPLATE_NAME}(#{VAPP_ID})" expiryTime="2011-11-16T13:27:38.407-08:00" name="task" id="urn:vcloud:task:#{FINALIZE_UPLOAD_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{FINALIZE_UPLOAD_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
          <Link rel="task:cancel" href="#{URL}/api/task/#{FINALIZE_UPLOAD_TASK_ID}/action/cancel"/>
          <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="#{VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
          <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
          <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
          <Progress>100</Progress>
        </Task>
        finalize_upload_task_done_response

        VAPP_TEMPLATE_READY_RESPONSE = <<-vapp_template_ready_response.strip()
<VAppTemplate xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" ovfDescriptorUploaded="true" goldMaster="false" status="8" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
    <Link rel="remove" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
    <Link rel="ovf" type="text/xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/ovf"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/metadata"/>
    <Description/>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <Children>
        <Vm goldMaster="false" name="vm1" id="urn:vcloud:vm:#{VM1_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}">
            <Link rel="up" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}/metadata"/>
            <Description>A virtual machine</Description>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}/networkConnectionSection/" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
                <NetworkConnection network="none" needsCustomization="true">
                    <NetworkConnectionIndex>0</NetworkConnectionIndex>
                    <IsConnected>false</IsConnected>
                    <MACAddress>00:50:56:02:00:fd</MACAddress>
                    <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
                </NetworkConnection>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{VM1_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
    </Children>
    <ovf:NetworkSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/networkSection/" vcloud:type="application/vnd.vmware.vcloud.networkSection+xml">
        <ovf:Info>The list of logical networks</ovf:Info>
        <ovf:Network ovf:name="none">
            <ovf:Description>This is a special place-holder used for disconnected network interfaces.</ovf:Description>
        </ovf:Network>
    </ovf:NetworkSection>
    <NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/networkConfigSection/" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
    <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
        <ovf:Info>Lease settings section</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/leaseSettingsSection/"/>
        <StorageLeaseInSeconds>7776000</StorageLeaseInSeconds>
        <StorageLeaseExpiration>2011-11-16T12:27:05.327-08:00</StorageLeaseExpiration>
    </LeaseSettingsSection>
    <CustomizationSection type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/customizationSection/" ovf:required="false">
        <ovf:Info>VApp template customization section</ovf:Info>
        <CustomizeOnInstantiate>true</CustomizeOnInstantiate>
        <Link rel="edit" type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{VAPP_ID}/customizationSection/"/>
    </CustomizationSection>
</VAppTemplate>
        vapp_template_ready_response

        VAPP_TEMPLATE_DELETE_TASK_ID = "909835c2-b4c4-4bce-b3da-d33650e25de2"

        VAPP_TEMPLATE_DELETE_TASK_LINK = "#{URL}/api/task/#{VAPP_TEMPLATE_DELETE_TASK_ID}"

        VAPP_TEMPLATE_DELETE_RUNNING_TASK = <<-vapp_template_delelete_running_task.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-08-18T13:29:19.328-07:00" operationName="vdcDeleteTemplate" operation="Deleting Virtual Application Template (#{VAPP_ID})" expiryTime="2011-11-16T13:29:19.328-08:00" name="task" id="urn:vcloud:task:#{VAPP_TEMPLATE_DELETE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{VAPP_TEMPLATE_DELETE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{VAPP_TEMPLATE_DELETE_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="" href="#{URL}/api/vAppTemplate/vappTemplate-6ce96611-43fa-4efd-8571-2804447a21c4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        vapp_template_delelete_running_task

        VAPP_TEMPLATE_DELETE_DONE_TASK = <<-vapp_template_delelete_done_task.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-08-18T13:29:19.328-07:00" operationName="vdcDeleteTemplate" operation="Deleting Virtual Application Template (#{VAPP_ID})" expiryTime="2011-11-16T13:29:19.328-08:00" name="task" id="urn:vcloud:task:#{VAPP_TEMPLATE_DELETE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{VAPP_TEMPLATE_DELETE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
    <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="" href="#{URL}/api/vAppTemplate/vappTemplate-6ce96611-43fa-4efd-8571-2804447a21c4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        vapp_template_delelete_done_task

        DELETED_VAPP_NAME = "already_deleted"

        EXISTING_VAPP_LINK = "#{URL}/api/vApp/vapp-#{EXISTING_VAPP_ID}"

        VAPP_TEMPLATE_INSTANTIATE_LINK = "#{URL}/api/vdc/#{VDC_ID}/action/instantiateVAppTemplate"

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_REQUEST = <<-vapp_template_instantiate_request.strip()
<ns7:InstantiateVAppTemplateParams xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns2="http://www.vmware.com/vcloud/v1" xmlns:ns3="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns4="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns5="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:ns6="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" xmlns:ns8="http://schemas.dmtf.org/ovf/environment/1" xmlns:ns9="http://www.vmware.com/vcloud/extension/v1.5" xmlns:ns10="http://www.vmware.com/vcloud/versions" linkedClone="false" powerOn="false" deploy="false" name="#{VAPP_NAME}">
  <ns7:Description></ns7:Description>
  <ns7:VAppParent href=""/>
  <ns7:InstantiationParams/>
  <ns7:Source href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}" id="urn:vcloud:vapptemplate:#{EXISTING_VAPP_TEMPLATE_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml"/>
  <ns7:IsSourceDelete>false</ns7:IsSourceDelete>
  <ns7:AllEULAsAccepted>true</ns7:AllEULAsAccepted>
</ns7:InstantiateVAppTemplateParams>
vapp_template_instantiate_request

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_WITH_LOCALITY_REQUEST = <<-vapp_template_instantiate_request.strip()
<ns7:InstantiateVAppTemplateParams xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns2="http://www.vmware.com/vcloud/v1" xmlns:ns3="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns4="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns5="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:ns6="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" xmlns:ns8="http://schemas.dmtf.org/ovf/environment/1" xmlns:ns9="http://www.vmware.com/vcloud/extension/v1.5" xmlns:ns10="http://www.vmware.com/vcloud/versions" linkedClone="false" powerOn="false" deploy="false" name="#{VAPP_NAME}">
  <ns7:Description>desc</ns7:Description>
  <ns7:VAppParent href=""/>
  <ns7:InstantiationParams/>
  <ns7:Source href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}" id="urn:vcloud:vapptemplate:#{EXISTING_VAPP_TEMPLATE_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml"/>
  <ns7:IsSourceDelete>false</ns7:IsSourceDelete>
  <ns7:SourcedVmInstantiationParams>
    <ns7:Source type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{VAPP_TEMPLATE_VM_URL}"/>
    <ns7:LocalityParams>
      <ns7:ResourceEntity type="application/vnd.vmware.vcloud.disk+xml" name="#{INDY_DISK_NAME}" href="#{INDY_DISK_URL}"/>
    </ns7:LocalityParams>
  </ns7:SourcedVmInstantiationParams>
  <ns7:AllEULAsAccepted>true</ns7:AllEULAsAccepted>
</ns7:InstantiateVAppTemplateParams>
vapp_template_instantiate_request

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID = "37be6f4c-69a8-4f80-ba94-271175967a68"

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_LINK = "#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}"

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_START_RESPONSE = <<-existing_vapp_template_instantiate_task_start_response.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-08-29T11:21:36.483-07:00" operationName="vdcInstantiateVapp" operation="Creating Virtual Application #{VAPP_NAME}(#{VAPP_ID})" expiryTime="2011-11-27T11:21:36.483-08:00" name="task" id="urn:vcloud:task:#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="#{VAPP_NAME}" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
    <Progress>1</Progress>
</Task>
        existing_vapp_template_instantiate_task_start_response

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_SUCCESS_RESPONSE = <<-existing_vapp_template_instantiate_task_success_response.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-08-29T11:21:36.483-07:00" operationName="vdcInstantiateVapp" operation="Creating Virtual Application #{VAPP_NAME}(#{VAPP_ID})" expiryTime="2011-11-27T11:21:36.483-08:00" name="task" id="urn:vcloud:task:#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="#{VAPP_NAME}" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
    <Progress>1</Progress>
</Task>
        existing_vapp_template_instantiate_task_success_response

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ERROR_RESPONSE = <<-existing_vapp_template_instantiate_task_error_response.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="error" startTime="2011-08-29T11:21:36.483-07:00" operationName="vdcInstantiateVapp" operation="Creating Virtual Application #{VAPP_NAME}(#{VAPP_ID})" expiryTime="2011-11-27T11:21:36.483-08:00" name="task" id="urn:vcloud:task:#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="#{VAPP_NAME}" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
    <Progress>1</Progress>
</Task>
        existing_vapp_template_instantiate_task_error_response

        EXISTING_VAPP_TEMPLATE_INSTANTIATE_RESPONSE  = <<-existing_vapp_template_instantiate_response.strip()
<VApp xmlns="http://www.vmware.com/vcloud/v1.5" deployed="false" status="0" name="#{VAPP_NAME}" id="urn:vcloud:vapp:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="down" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/controlAccess/"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/metadata"/>
    <Description>test</Description>
    <Tasks>
        <Task status="running" startTime="2011-08-29T11:21:36.484-07:00" operationName="vdcInstantiateVapp" operation="Creating Virtual Application #{VAPP_NAME}(#{VAPP_ID})" expiryTime="2011-11-27T11:21:36.484-08:00" name="task" id="urn:vcloud:task:#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}">
            <Link rel="task:cancel" href="#{URL}/api/task/#{EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ID}/action/cancel"/>
            <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="#{VAPP_NAME}" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
            <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
            <Progress>1</Progress>
        </Task>
    </Tasks>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <InMaintenanceMode>false</InMaintenanceMode>
</VApp>
        existing_vapp_template_instantiate_response

        EXISTING_VAPP_TEMPLATE_CATALOG_URN = "urn:vcloud:catalogitem:#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"
        EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_URL = "#{URL}/api/entity/#{EXISTING_VAPP_TEMPLATE_CATALOG_URN}"
        EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_LINK = "#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"

        EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_RESPONSE = <<-existing_vapp_template_item_response.strip()
        <CatalogItem xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="#{EXISTING_VAPP_TEMPLATE_NAME}" id="urn:vcloud:catalogitem:39a8f899-0f8e-40c4-ac68-66b2688833bc" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
            <Link rel="up" type="application/vnd.vmware.vcloud.catalog+xml" href="#{URL}/api/catalog/#{CATALOG_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}/metadata"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"/>
            <Link rel="remove" href="#{URL}/api/catalogItem/#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_ID}"/>
            <Description/>
            <Entity type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="#{EXISTING_VAPP_TEMPLATE_NAME}" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"/>
        </CatalogItem>
        existing_vapp_template_item_response

        VAPP_TEMPLATE_CATALOG_URN = "urn:vcloud:catalogitem:39a8f899-0f8e-40c4-ac68-66b2688833bc"
        VAPP_TEMPLATE_CATALOG_RESOLVER_URL = "#{URL}/api/entity/#{VAPP_TEMPLATE_CATALOG_URN}"
        VAPP_TEMPLATE_CATALOG_ITEM_LINK = "#{URL}/api/catalogItem/39a8f899-0f8e-40c4-ac68-66b2688833bc"

        EXISTING_VAPP_TEMPLATE_LINK = "#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"

        EXISTING_VAPP_TEMPLATE_READY_RESPONSE = <<-existing_vapp_template_ready_response.strip()
<VAppTemplate xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" ovfDescriptorUploaded="true" goldMaster="false" status="8" name="#{VAPP_TEMPLATE_NAME}" id="urn:vcloud:vapptemplate:#{EXISTING_VAPP_TEMPLATE_ID}" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/#{VDC_ID}"/>
    <Link rel="remove" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"/>
    <Link rel="ovf" type="text/xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/ovf"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/metadata"/>
    <Description/>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <Children>
        <Vm goldMaster="false" name="vm1" id="urn:vcloud:vm:#{VM1_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}">
            <Link rel="up" type="application/vnd.vmware.vcloud.vAppTemplate+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}/metadata"/>
            <Description>A virtual machine</Description>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}/networkConnectionSection/" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
                <NetworkConnection network="none" needsCustomization="true">
                    <NetworkConnectionIndex>0</NetworkConnectionIndex>
                    <IsConnected>false</IsConnected>
                    <MACAddress>00:50:56:02:00:fd</MACAddress>
                    <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
                </NetworkConnection>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vAppTemplate/vm-#{VM1_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{VM1_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
    </Children>
    <ovf:NetworkSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/networkSection/" vcloud:type="application/vnd.vmware.vcloud.networkSection+xml">
        <ovf:Info>The list of logical networks</ovf:Info>
        <ovf:Network ovf:name="none">
            <ovf:Description>This is a special place-holder used for disconnected network interfaces.</ovf:Description>
        </ovf:Network>
    </ovf:NetworkSection>
    <NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/networkConfigSection/" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
    <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/leaseSettingsSection/" ovf:required="false">
        <ovf:Info>Lease settings section</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/leaseSettingsSection/"/>
        <StorageLeaseInSeconds>7776000</StorageLeaseInSeconds>
        <StorageLeaseExpiration>2011-11-16T12:27:05.327-08:00</StorageLeaseExpiration>
    </LeaseSettingsSection>
    <CustomizationSection type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/customizationSection/" ovf:required="false">
        <ovf:Info>VApp template customization section</ovf:Info>
        <CustomizeOnInstantiate>true</CustomizeOnInstantiate>
        <Link rel="edit" type="application/vnd.vmware.vcloud.customizationSection+xml" href="#{URL}/api/vAppTemplate/vappTemplate-#{EXISTING_VAPP_TEMPLATE_ID}/customizationSection/"/>
    </CustomizationSection>
</VAppTemplate>
        existing_vapp_template_ready_response

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

        INSTANTIATED_VM_INSERT_MEDIA_TASK_ID = 'dd3a1c3c-6e4a-4783-9e18-d95e65dd260c'

        INSTANTIATED_VM_INSERT_MEDIA_TASK_LINK = "#{URL}/api/task/#{INSTANTIATED_VM_INSERT_MEDIA_TASK_ID}"

        INSTANTIATED_VM_INSERT_MEDIA_TASK_DONE = <<-HEREDOC.strip()
        <Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-23T15:34:12.094-07:00" operationName="vappInsertCdFloppy" operation="Inserting Media Virtual Machine (4cad7e64-b201-4042-8892-8dfa50ed5516)" expiryTime="2011-12-22T15:34:12.094-08:00" name="task" id="urn:vcloud:task:#{INSTANTIATED_VM_INSERT_MEDIA_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
            <Link rel="task:cancel" href="#{URL}/api/task/#{INSTANTIATED_VM_INSERT_MEDIA_TASK_ID}/action/cancel"/>
            <Owner type="application/vnd.vmware.vcloud.vm+xml" name="" href="#{URL}/api/vApp/vm-4cad7e64-b201-4042-8892-8dfa50ed5516"/>
            <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
        </Task>
        HEREDOC

        INSTANTIATED_VM_ATTACH_DISK_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/disk/action/attach"

        INSTANTIATED_VM_DETACH_DISK_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/disk/action/detach"

        INSTANTIAED_VAPP_RESPONSE = <<-instantiated_vapp_response.strip()
<VApp xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" deployed="false" status="8" name="test_vapp15_1" id="urn:vcloud:vapp:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{INSTANTIATED_VAPP_POWER_ON_LINK}"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/deploy"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/controlAccess/"/>
    <Link rel="controlAccess" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/controlAccess"/>
    <Link rel="recompose" type="application/vnd.vmware.vcloud.recomposeVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/recomposeVApp"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/metadata"/>
    <Description>test</Description>
    <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
        <ovf:Info>Lease settings section</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/"/>
        <DeploymentLeaseInSeconds>604800</DeploymentLeaseInSeconds>
        <StorageLeaseInSeconds>2592000</StorageLeaseInSeconds>
        <StorageLeaseExpiration>2011-09-28T11:21:35.767-07:00</StorageLeaseExpiration>
    </LeaseSettingsSection>
    <ovf:StartupSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/" vcloud:type="application/vnd.vmware.vcloud.startupSection+xml">
        <ovf:Info>VApp startup section</ovf:Info>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="1" ovf:id="vm1"/>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="2" ovf:id="vm2"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.startupSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/"/>
    </ovf:StartupSection>
    <ovf:NetworkSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/networkSection/" vcloud:type="application/vnd.vmware.vcloud.networkSection+xml">
        <ovf:Info>The list of logical networks</ovf:Info>
        <ovf:Network ovf:name="none">
            <ovf:Description>This is a special place-holder used for disconnected network interfaces.</ovf:Description>
        </ovf:Network>
    </ovf:NetworkSection>
    <NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <InMaintenanceMode>false</InMaintenanceMode>
    <Children>
        <Vm needsCustomization="true" deployed="false" status="8" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{INSTANTIATED_VM_LINK}">
            <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
            <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="reconfigureVm" type="application/vnd.vmware.vcloud.vm+xml" name="vm1" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/reconfigureVm"/>
            <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
            <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
            <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
            <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
            <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
            <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
            <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
            <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
            <Description>A virtual machine</Description>
            <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Virtual hardware requirements</ovf:Info>
                <ovf:System>
                    <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
                    <vssd:InstanceID>0</vssd:InstanceID>
                    <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
                    <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
                </ovf:System>
                <ovf:Item>
                    <rasd:Address>00:50:56:02:01:56</rasd:Address>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
                    <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
                    <rasd:ElementName>Network adapter 0</rasd:ElementName>
                    <rasd:InstanceID>1</rasd:InstanceID>
                    <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
                    <rasd:ResourceType>10</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>SCSI Controller</rasd:Description>
                    <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
                    <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
                    <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
                    <rasd:ResourceType>6</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:Description>Hard disk</rasd:Description>
                    <rasd:ElementName>Hard disk 1</rasd:ElementName>
                    <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
                    <rasd:InstanceID>2000</rasd:InstanceID>
                    <rasd:Parent>2</rasd:Parent>
                    <rasd:ResourceType>17</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>IDE Controller</rasd:Description>
                    <rasd:ElementName>IDE Controller 0</rasd:ElementName>
                    <rasd:InstanceID>3</rasd:InstanceID>
                    <rasd:ResourceType>5</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>CD/DVD Drive</rasd:Description>
                    <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>3000</rasd:InstanceID>
                    <rasd:Parent>3</rasd:Parent>
                    <rasd:ResourceType>15</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>Floppy Drive</rasd:Description>
                    <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>8000</rasd:InstanceID>
                    <rasd:ResourceType>14</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
                    <rasd:Description>Number of Virtual CPUs</rasd:Description>
                    <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
                    <rasd:InstanceID>4</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>3</rasd:ResourceType>
                    <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
                    <rasd:Description>Memory Size</rasd:Description>
                    <rasd:ElementName>32 MB of memory</rasd:ElementName>
                    <rasd:InstanceID>5</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>4</rasd:ResourceType>
                    <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                </ovf:Item>
                <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
            </ovf:VirtualHardwareSection>
            <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
                <ovf:Info>Specifies the operating system installed</ovf:Info>
                <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
                <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
            </ovf:OperatingSystemSection>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
                <NetworkConnection network="none" needsCustomization="true">
                    <NetworkConnectionIndex>0</NetworkConnectionIndex>
                    <IsConnected>false</IsConnected>
                    <MACAddress>00:50:56:02:01:56</MACAddress>
                    <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
                </NetworkConnection>
                <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
                <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Specifies Runtime info</ovf:Info>
            </RuntimeInfoSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
    </Children>
</VApp>
        instantiated_vapp_response

        INSTANTIAED_VAPP_ON_RESPONSE = <<-instantiated_vapp_on_response.strip()
<VApp xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" deployed="false" status="4" name="test_vapp15_1" id="urn:vcloud:vapp:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOff" href="#{INSTANTIATED_VAPP_POWER_OFF_LINK}"/>
    <Link rel="power:reboot" href="#{INSTANTIATED_VAPP_POWER_REBOOT_LINK}"/>
    <Link rel="undeploy" type="application/vnd.vmware.vcloud.undeployVAppParams+xml" href="#{INSTANTIATED_VAPP_UNDEPLOY_LINK}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/controlAccess/"/>
    <Link rel="controlAccess" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/controlAccess"/>
    <Link rel="recompose" type="application/vnd.vmware.vcloud.recomposeVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/recomposeVApp"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/metadata"/>
    <Description>test</Description>
    <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
        <ovf:Info>Lease settings section</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/"/>
        <DeploymentLeaseInSeconds>604800</DeploymentLeaseInSeconds>
        <StorageLeaseInSeconds>2592000</StorageLeaseInSeconds>
        <StorageLeaseExpiration>2011-09-28T11:21:35.767-07:00</StorageLeaseExpiration>
    </LeaseSettingsSection>
    <ovf:StartupSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/" vcloud:type="application/vnd.vmware.vcloud.startupSection+xml">
        <ovf:Info>VApp startup section</ovf:Info>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="1" ovf:id="vm1"/>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="2" ovf:id="vm2"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.startupSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/"/>
    </ovf:StartupSection>
    <ovf:NetworkSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/networkSection/" vcloud:type="application/vnd.vmware.vcloud.networkSection+xml">
        <ovf:Info>The list of logical networks</ovf:Info>
        <ovf:Network ovf:name="none">
            <ovf:Description>This is a special place-holder used for disconnected network interfaces.</ovf:Description>
        </ovf:Network>
    </ovf:NetworkSection>
    <NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <InMaintenanceMode>false</InMaintenanceMode>
    <Children>
        <Vm needsCustomization="true" deployed="false" status="8" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{INSTANTIATED_VM_LINK}">
            <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
            <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
            <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
            <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
            <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
            <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
            <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
            <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
            <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
            <Description>A virtual machine</Description>
            <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Virtual hardware requirements</ovf:Info>
                <ovf:System>
                    <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
                    <vssd:InstanceID>0</vssd:InstanceID>
                    <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
                    <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
                </ovf:System>
                <ovf:Item>
                    <rasd:Address>00:50:56:02:01:56</rasd:Address>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
                    <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
                    <rasd:ElementName>Network adapter 0</rasd:ElementName>
                    <rasd:InstanceID>1</rasd:InstanceID>
                    <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
                    <rasd:ResourceType>10</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>SCSI Controller</rasd:Description>
                    <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
                    <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
                    <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
                    <rasd:ResourceType>6</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:Description>Hard disk</rasd:Description>
                    <rasd:ElementName>Hard disk 1</rasd:ElementName>
                    <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
                    <rasd:InstanceID>2000</rasd:InstanceID>
                    <rasd:Parent>2</rasd:Parent>
                    <rasd:ResourceType>17</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>IDE Controller</rasd:Description>
                    <rasd:ElementName>IDE Controller 0</rasd:ElementName>
                    <rasd:InstanceID>3</rasd:InstanceID>
                    <rasd:ResourceType>5</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>CD/DVD Drive</rasd:Description>
                    <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>3000</rasd:InstanceID>
                    <rasd:Parent>3</rasd:Parent>
                    <rasd:ResourceType>15</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>Floppy Drive</rasd:Description>
                    <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>8000</rasd:InstanceID>
                    <rasd:ResourceType>14</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
                    <rasd:Description>Number of Virtual CPUs</rasd:Description>
                    <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
                    <rasd:InstanceID>4</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>3</rasd:ResourceType>
                    <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
                    <rasd:Description>Memory Size</rasd:Description>
                    <rasd:ElementName>32 MB of memory</rasd:ElementName>
                    <rasd:InstanceID>5</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>4</rasd:ResourceType>
                    <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                </ovf:Item>
                <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
            </ovf:VirtualHardwareSection>
            <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
                <ovf:Info>Specifies the operating system installed</ovf:Info>
                <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
                <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
            </ovf:OperatingSystemSection>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
                <NetworkConnection network="none" needsCustomization="true">
                    <NetworkConnectionIndex>0</NetworkConnectionIndex>
                    <IsConnected>false</IsConnected>
                    <MACAddress>00:50:56:02:01:56</MACAddress>
                    <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
                </NetworkConnection>
                <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
                <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Specifies Runtime info</ovf:Info>
            </RuntimeInfoSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
    </Children>
</VApp>
        instantiated_vapp_on_response


        INSTANTIAED_VAPP_POWERED_OFF_RESPONSE = <<-instantiated_vapp_off_response.strip()
<VApp xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" deployed="false" status="8" name="#{VAPP_NAME}" id="urn:vcloud:vapp:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{INSTANTIATED_VAPP_POWER_ON_LINK}"/>
    <Link rel="power:powerOff" href="#{INSTANTIATED_VAPP_POWER_OFF_LINK}"/>
    <Link rel="undeploy" type="application/vnd.vmware.vcloud.undeployVAppParams+xml" href="#{INSTANTIATED_VAPP_UNDEPLOY_LINK}"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/deploy"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/controlAccess/"/>
    <Link rel="controlAccess" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/controlAccess"/>
    <Link rel="recompose" type="application/vnd.vmware.vcloud.recomposeVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/recomposeVApp"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/metadata"/>
    <Description>test</Description>
    <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
        <ovf:Info>Lease settings section</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/"/>
        <DeploymentLeaseInSeconds>604800</DeploymentLeaseInSeconds>
        <StorageLeaseInSeconds>2592000</StorageLeaseInSeconds>
        <StorageLeaseExpiration>2011-09-28T11:21:35.767-07:00</StorageLeaseExpiration>
    </LeaseSettingsSection>
    <ovf:StartupSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/" vcloud:type="application/vnd.vmware.vcloud.startupSection+xml">
        <ovf:Info>VApp startup section</ovf:Info>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="1" ovf:id="vm1"/>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="2" ovf:id="vm2"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.startupSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/"/>
    </ovf:StartupSection>
    <ovf:NetworkSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/networkSection/" vcloud:type="application/vnd.vmware.vcloud.networkSection+xml">
        <ovf:Info>The list of logical networks</ovf:Info>
        <ovf:Network ovf:name="none">
            <ovf:Description>This is a special place-holder used for disconnected network interfaces.</ovf:Description>
        </ovf:Network>
    </ovf:NetworkSection>
    <NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <InMaintenanceMode>false</InMaintenanceMode>
    <Children>
        <Vm needsCustomization="true" deployed="false" status="8" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{INSTANTIATED_VM_LINK}">
            <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
            <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
            <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
            <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
            <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
            <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
            <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
            <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
            <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
            <Description>A virtual machine</Description>
            <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Virtual hardware requirements</ovf:Info>
                <ovf:System>
                    <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
                    <vssd:InstanceID>0</vssd:InstanceID>
                    <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
                    <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
                </ovf:System>
                <ovf:Item>
                    <rasd:Address>00:50:56:02:01:56</rasd:Address>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
                    <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
                    <rasd:ElementName>Network adapter 0</rasd:ElementName>
                    <rasd:InstanceID>1</rasd:InstanceID>
                    <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
                    <rasd:ResourceType>10</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>SCSI Controller</rasd:Description>
                    <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
                    <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
                    <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
                    <rasd:ResourceType>6</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:Description>Hard disk</rasd:Description>
                    <rasd:ElementName>Hard disk 1</rasd:ElementName>
                    <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
                    <rasd:InstanceID>2000</rasd:InstanceID>
                    <rasd:Parent>2</rasd:Parent>
                    <rasd:ResourceType>17</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>IDE Controller</rasd:Description>
                    <rasd:ElementName>IDE Controller 0</rasd:ElementName>
                    <rasd:InstanceID>3</rasd:InstanceID>
                    <rasd:ResourceType>5</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>CD/DVD Drive</rasd:Description>
                    <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>3000</rasd:InstanceID>
                    <rasd:Parent>3</rasd:Parent>
                    <rasd:ResourceType>15</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>Floppy Drive</rasd:Description>
                    <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>8000</rasd:InstanceID>
                    <rasd:ResourceType>14</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
                    <rasd:Description>Number of Virtual CPUs</rasd:Description>
                    <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
                    <rasd:InstanceID>4</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>3</rasd:ResourceType>
                    <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
                    <rasd:Description>Memory Size</rasd:Description>
                    <rasd:ElementName>32 MB of memory</rasd:ElementName>
                    <rasd:InstanceID>5</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>4</rasd:ResourceType>
                    <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                </ovf:Item>
                <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
            </ovf:VirtualHardwareSection>
            <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
                <ovf:Info>Specifies the operating system installed</ovf:Info>
                <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
                <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
            </ovf:OperatingSystemSection>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
                <NetworkConnection network="none" needsCustomization="true">
                    <NetworkConnectionIndex>0</NetworkConnectionIndex>
                    <IsConnected>false</IsConnected>
                    <MACAddress>00:50:56:02:01:56</MACAddress>
                    <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
                </NetworkConnection>
                <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
                <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Specifies Runtime info</ovf:Info>
            </RuntimeInfoSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
    </Children>
</VApp>
        instantiated_vapp_off_response


        INSTANTIATED_SUSPENDED_VAPP_RESPONSE = <<-instantiated_suspended_vapp_response.strip()
<VApp xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" deployed="false" status="3" name="test_vapp15_1" id="urn:vcloud:vapp:#{VAPP_ID}" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{INSTANTIATED_VAPP_POWER_ON_LINK}"/>
    <Link rel="power:suspend" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/power/action/suspend"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/deploy"/>
    <Link rel="undeploy" type="application/vnd.vmware.vcloud.undeployVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/undeploy"/>
    <Link rel="discardState" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/discardSuspendedState"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/controlAccess/"/>
    <Link rel="controlAccess" type="application/vnd.vmware.vcloud.controlAccess+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/controlAccess"/>
    <Link rel="recompose" type="application/vnd.vmware.vcloud.recomposeVAppParams+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/action/recomposeVApp"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/a974dae0-d10c-4f7c-9f4f-4bdaf7826a3a"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/metadata"/>
    <Description>test</Description>
    <LeaseSettingsSection type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/" ovf:required="false">
        <ovf:Info>Lease settings section</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.leaseSettingsSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/leaseSettingsSection/"/>
        <DeploymentLeaseInSeconds>604800</DeploymentLeaseInSeconds>
        <StorageLeaseInSeconds>2592000</StorageLeaseInSeconds>
        <StorageLeaseExpiration>2011-09-28T11:21:35.767-07:00</StorageLeaseExpiration>
    </LeaseSettingsSection>
    <ovf:StartupSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/" vcloud:type="application/vnd.vmware.vcloud.startupSection+xml">
        <ovf:Info>VApp startup section</ovf:Info>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="1" ovf:id="vm1"/>
        <ovf:Item ovf:stopDelay="120" ovf:stopAction="powerOff" ovf:startDelay="120" ovf:startAction="powerOn" ovf:order="2" ovf:id="vm2"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.startupSection+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}/startupSection/"/>
    </ovf:StartupSection>
    <ovf:NetworkSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vapp-#{VAPP_ID}/networkSection/" vcloud:type="application/vnd.vmware.vcloud.networkSection+xml">
        <ovf:Info>The list of logical networks</ovf:Info>
        <ovf:Network ovf:name="none">
            <ovf:Description>This is a special place-holder used for disconnected network interfaces.</ovf:Description>
        </ovf:Network>
    </ovf:NetworkSection>
    <NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
    <InMaintenanceMode>false</InMaintenanceMode>
    <Children>
        <Vm needsCustomization="true" deployed="false" status="3" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{INSTANTIATED_VM_LINK}">
            <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
            <Link rel="power:suspend" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/suspend"/>
            <Link rel="undeploy" type="application/vnd.vmware.vcloud.undeployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/undeploy"/>
            <Link rel="discardState" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/discardSuspendedState"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
            <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
            <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
            <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
            <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
            <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
            <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
            <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-#{VAPP_ID}"/>
            <Description>A virtual machine</Description>
            <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Virtual hardware requirements</ovf:Info>
                <ovf:System>
                    <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
                    <vssd:InstanceID>0</vssd:InstanceID>
                    <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
                    <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
                </ovf:System>
                <ovf:Item>
                    <rasd:Address>00:50:56:02:01:56</rasd:Address>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
                    <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
                    <rasd:ElementName>Network adapter 0</rasd:ElementName>
                    <rasd:InstanceID>1</rasd:InstanceID>
                    <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
                    <rasd:ResourceType>10</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>SCSI Controller</rasd:Description>
                    <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
                    <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
                    <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
                    <rasd:ResourceType>6</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:Description>Hard disk</rasd:Description>
                    <rasd:ElementName>Hard disk 1</rasd:ElementName>
                    <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
                    <rasd:InstanceID>2000</rasd:InstanceID>
                    <rasd:Parent>2</rasd:Parent>
                    <rasd:ResourceType>17</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>IDE Controller</rasd:Description>
                    <rasd:ElementName>IDE Controller 0</rasd:ElementName>
                    <rasd:InstanceID>3</rasd:InstanceID>
                    <rasd:ResourceType>5</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>CD/DVD Drive</rasd:Description>
                    <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>3000</rasd:InstanceID>
                    <rasd:Parent>3</rasd:Parent>
                    <rasd:ResourceType>15</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>Floppy Drive</rasd:Description>
                    <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>8000</rasd:InstanceID>
                    <rasd:ResourceType>14</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
                    <rasd:Description>Number of Virtual CPUs</rasd:Description>
                    <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
                    <rasd:InstanceID>4</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>3</rasd:ResourceType>
                    <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
                    <rasd:Description>Memory Size</rasd:Description>
                    <rasd:ElementName>32 MB of memory</rasd:ElementName>
                    <rasd:InstanceID>5</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>4</rasd:ResourceType>
                    <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                </ovf:Item>
                <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
            </ovf:VirtualHardwareSection>
            <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
                <ovf:Info>Specifies the operating system installed</ovf:Info>
                <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
                <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
            </ovf:OperatingSystemSection>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
                <NetworkConnection network="none" needsCustomization="true">
                    <NetworkConnectionIndex>0</NetworkConnectionIndex>
                    <IsConnected>false</IsConnected>
                    <MACAddress>00:50:56:02:01:56</MACAddress>
                    <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
                </NetworkConnection>
                <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
                <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Specifies Runtime info</ovf:Info>
            </RuntimeInfoSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
    </Children>
</VApp>
        instantiated_suspended_vapp_response

        INSTANTIATED_VAPP_DELETE_TASK_ID = "2637f9de-4a68-4829-9515-469788a4e36a"

        INSTANTIATED_VAPP_DELETE_TASK_LINK = "#{URL}/api/task/#{INSTANTIATED_VAPP_DELETE_TASK_ID}"

        INSTANTIATED_VAPP_DELETE_RUNNING_TASK = <<-instantiated_vapp_delelete_running_task.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-08-18T13:29:19.328-07:00" operationName="vdcDeleteTemplate" operation="Deleting Virtual Application Template (#{VAPP_ID})" expiryTime="2011-11-16T13:29:19.328-08:00" name="task" id="urn:vcloud:task:#{INSTANTIATED_VAPP_DELETE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{INSTANTIATED_VAPP_DELETE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{INSTANTIATED_VAPP_DELETE_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="" href="#{URL}/api/vAppTemplate/vappTemplate-6ce96611-43fa-4efd-8571-2804447a21c4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vapp_delelete_running_task

        INSTANTIATED_VAPP_DELETE_DONE_TASK = <<-instantiated_vapp_delelete_done_task.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-08-18T13:29:19.328-07:00" operationName="vdcDeleteTemplate" operation="Deleting Virtual Application Template (#{VAPP_ID})" expiryTime="2011-11-16T13:29:19.328-08:00" name="task" id="urn:vcloud:task:#{INSTANTIATED_VAPP_DELETE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/#{INSTANTIATED_VAPP_DELETE_TASK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 #{URL}/api/v1.5/schema/master.xsd">
    <Owner type="application/vnd.vmware.vcloud.vAppTemplate+xml" name="" href="#{URL}/api/vAppTemplate/vappTemplate-6ce96611-43fa-4efd-8571-2804447a21c4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vapp_delelete_done_task

        INSTANTIATED_VAPP_POWER_ON_TASK_ID = "d202bc01-3a7e-4683-adac-bfc76fdf1293"

        INSTANTIATED_VAPP_POWER_ON_TASK_LINK = "#{URL}/api/task/#{INSTANTIATED_VAPP_POWER_ON_TASK_ID}"

        INSTANTED_VAPP_POWER_TASK_RUNNING = <<-instantiated_vapp_power_task_running
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-09-12T08:47:40.356-07:00" operationName="vappDeploy" operation="Starting Virtual Application test17_3_8(2b685484-ed2f-48c3-9396-5ad29cb282f4)" expiryTime="2011-12-11T08:47:40.356-08:00" name="task" id="urn:vcloud:task:#{INSTANTIATED_VAPP_POWER_ON_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTIATED_VAPP_POWER_ON_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{INSTANTIATED_VAPP_POWER_ON_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="#{VAPP_NAME}" href="#{URL}/api/vApp/vapp-2b685484-ed2f-48c3-9396-5ad29cb282f4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vapp_power_task_running

        INSTANTED_VAPP_POWER_TASK_SUCCESS = <<-instantiated_vapp_power_task_success
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-12T08:47:40.356-07:00" operationName="vappDeploy" operation="Starting Virtual Application test17_3_8(2b685484-ed2f-48c3-9396-5ad29cb282f4)" expiryTime="2011-12-11T08:47:40.356-08:00" name="task" id="urn:vcloud:task:#{INSTANTIATED_VAPP_POWER_ON_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTIATED_VAPP_POWER_ON_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/#{INSTANTIATED_VAPP_POWER_ON_TASK_ID}/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="#{VAPP_NAME}" href="#{URL}/api/vApp/vapp-2b685484-ed2f-48c3-9396-5ad29cb282f4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vapp_power_task_success


        INSTANTIATED_VM_CPU_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"

        INSTANTIATED_VM_CPU_RESPONSE = <<-instantiated_vm_cpu_response.strip()
        <Item xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </Item>
        instantiated_vm_cpu_response

        INSTANTIATED_VM_CPU_REQUEST = <<-instantiated_vm_cpu_request.strip()
    <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>#{CPU}</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
        instantiated_vm_cpu_request

        INSTANTIATED_VM_MEMORY_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"

        INSTANTIATED_VM_MEMORY_RESPONSE = <<-instantiated_vm_cpu_response.strip()
        <Item xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </Item>
        instantiated_vm_cpu_response

        INSTANTIATED_VM_MEMORY_REQUEST = <<-instantiated_vm_memory_request.strip()
    <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>#{MEMORY}</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
        instantiated_vm_memory_request


        INSTANTIATED_VM_RESPONSE = <<-instantiated_vm_response.strip()
<Vm xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" needsCustomization="true" deployed="false" status="8" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
    <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
    <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
    <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
    <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
    <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
    <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-81f65d6c-80b0-4695-a4b1-57ae1f15d795"/>
    <Description>A virtual machine</Description>
    <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
    <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
        <ovf:Info>Specifies the operating system installed</ovf:Info>
        <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
        <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
    </ovf:OperatingSystemSection>
    <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
        <ovf:Info>Specifies the available VM network connections</ovf:Info>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="none" needsCustomization="true">
            <NetworkConnectionIndex>0</NetworkConnectionIndex>
            <IsConnected>false</IsConnected>
            <MACAddress>00:50:56:02:01:cb</MACAddress>
            <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
        </NetworkConnection>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
    </NetworkConnectionSection>
    <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
        <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
        <Enabled>false</Enabled>
        <ChangeSid>false</ChangeSid>
        <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
        <JoinDomainEnabled>false</JoinDomainEnabled>
        <UseOrgSettings>false</UseOrgSettings>
        <AdminPasswordEnabled>true</AdminPasswordEnabled>
        <AdminPasswordAuto>true</AdminPasswordAuto>
        <ResetPasswordRequired>false</ResetPasswordRequired>
        <ComputerName>vm1-001</ComputerName>
        <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
    </GuestCustomizationSection>
    <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
        <ovf:Info>Information about the installed software</ovf:Info>
        <ovf:Product>UnOS</ovf:Product>
    </ovf:ProductSection>
    <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Specifies Runtime info</ovf:Info>
    </RuntimeInfoSection>
    <VAppScopedLocalId>vm1</VAppScopedLocalId>
</Vm>
        instantiated_vm_response

        INSTANTIATED_VM_NO_DESCRIPTION_RESPONSE = <<-instantiated_vm_no_description_response.strip()
<Vm xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" needsCustomization="true" deployed="false" status="8" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
    <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
    <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
    <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
    <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
    <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
    <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-81f65d6c-80b0-4695-a4b1-57ae1f15d795"/>
    <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
    <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
        <ovf:Info>Specifies the operating system installed</ovf:Info>
        <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
        <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
    </ovf:OperatingSystemSection>
    <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
        <ovf:Info>Specifies the available VM network connections</ovf:Info>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="none" needsCustomization="true">
            <NetworkConnectionIndex>0</NetworkConnectionIndex>
            <IsConnected>false</IsConnected>
            <MACAddress>00:50:56:02:01:cb</MACAddress>
            <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
        </NetworkConnection>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
    </NetworkConnectionSection>
    <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
        <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
        <Enabled>false</Enabled>
        <ChangeSid>false</ChangeSid>
        <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
        <JoinDomainEnabled>false</JoinDomainEnabled>
        <UseOrgSettings>false</UseOrgSettings>
        <AdminPasswordEnabled>true</AdminPasswordEnabled>
        <AdminPasswordAuto>true</AdminPasswordAuto>
        <ResetPasswordRequired>false</ResetPasswordRequired>
        <ComputerName>vm1-001</ComputerName>
        <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
    </GuestCustomizationSection>
    <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
        <ovf:Info>Information about the installed software</ovf:Info>
        <ovf:Product>UnOS</ovf:Product>
    </ovf:ProductSection>
    <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Specifies Runtime info</ovf:Info>
    </RuntimeInfoSection>
    <VAppScopedLocalId>vm1</VAppScopedLocalId>
</Vm>
        instantiated_vm_no_description_response

        INSTANTIATED_VM_RESPONSE_WITH_SERVER_DEFINED_NAMESPACE = <<-instantiated_vm_response_server_defined_ns.strip()
<Vm xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" needsCustomization="true" deployed="false" dateCreated="2012-01-13T14:03:07.533-08:00" status="8" name="vm1" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
    <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
    <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
    <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
    <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
    <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
    <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-81f65d6c-80b0-4695-a4b1-57ae1f15d795"/>
    <Description>A virtual machine</Description>
    <ovf:VirtualHardwareSection xmlns:ns8="http://www.vmware.com/vcloud/v1.5" ovf:transport="" ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" ns8:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection ns8:primaryNetworkConnection="true" ns8:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource ns8:capacity="200" ns8:busSubType="lsilogic" ns8:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" ns8:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" ns8:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
    <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
        <ovf:Info>Specifies the operating system installed</ovf:Info>
        <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
        <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
    </ovf:OperatingSystemSection>
    <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
        <ovf:Info>Specifies the available VM network connections</ovf:Info>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="none" needsCustomization="true">
            <NetworkConnectionIndex>0</NetworkConnectionIndex>
            <IsConnected>false</IsConnected>
            <MACAddress>00:50:56:02:01:cb</MACAddress>
            <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
        </NetworkConnection>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
    </NetworkConnectionSection>
    <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
        <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
        <Enabled>false</Enabled>
        <ChangeSid>false</ChangeSid>
        <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
        <JoinDomainEnabled>false</JoinDomainEnabled>
        <UseOrgSettings>false</UseOrgSettings>
        <AdminPasswordEnabled>true</AdminPasswordEnabled>
        <AdminPasswordAuto>true</AdminPasswordAuto>
        <ResetPasswordRequired>false</ResetPasswordRequired>
        <ComputerName>vm1-001</ComputerName>
        <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
    </GuestCustomizationSection>
    <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
        <ovf:Info>Information about the installed software</ovf:Info>
        <ovf:Product>UnOS</ovf:Product>
    </ovf:ProductSection>
    <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Specifies Runtime info</ovf:Info>
    </RuntimeInfoSection>
    <VAppScopedLocalId>vm1</VAppScopedLocalId>
</Vm>
        instantiated_vm_response_server_defined_ns

        INSTANTIATED_VM_MODIFY_TASK_LINK = "#{URL}/api/task/16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7"

        INSTANTIATED_VM_MODIFY_TASK_RUNNING = <<-instantiated_vm_modify_task_running
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-09-01T14:45:50.110-07:00" operationName="vappUpdateVm" operation="Updating Virtual Machine #{VM_NAME}(#{INSTANTIATED_VM_ID})" expiryTime="2011-11-30T14:45:50.110-08:00" name="task" id="urn:vcloud:task:16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vm_modify_task_running

        INSTANTIATED_VM_MODIFY_TASK_SUCCESS = <<-instantiated_vm_modify_task_running
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-01T14:45:50.110-07:00" operationName="vappUpdateVm" operation="Updating Virtual Machine #{VM_NAME}(#{INSTANTIATED_VM_ID})" expiryTime="2011-11-30T14:45:50.110-08:00" name="task" id="urn:vcloud:task:16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vm_modify_task_running

        INSTANTIATED_VM_MODIFY_TASK_ERROR = <<-instantiated_vm_modify_task_running
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="error" startTime="2011-09-01T14:45:50.110-07:00" operationName="vappUpdateVm" operation="Updating Virtual Machine #{VM_NAME}(#{INSTANTIATED_VM_ID})" expiryTime="2011-11-30T14:45:50.110-08:00" name="task" id="urn:vcloud:task:16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/16edd9b8-ae1f-4d2f-b3a3-cc27348b37f7" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vm_modify_task_running

        INSTANTIATED_VM_NAME_CHANGE_REQUEST = <<-instantiated_vm_name_change_request.strip()
<Vm xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" needsCustomization="true" deployed="false" status="8" name="#{CHANGED_VM_NAME}" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
    <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
    <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
    <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
    <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
    <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
    <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-81f65d6c-80b0-4695-a4b1-57ae1f15d795"/>
    <Description>#{CHANGED_VM_DESCRIPTION}</Description>
    <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
    <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
        <ovf:Info>Specifies the operating system installed</ovf:Info>
        <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
        <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
    </ovf:OperatingSystemSection>
    <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
        <ovf:Info>Specifies the available VM network connections</ovf:Info>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="none" needsCustomization="true">
            <NetworkConnectionIndex>0</NetworkConnectionIndex>
            <IsConnected>false</IsConnected>
            <MACAddress>00:50:56:02:01:cb</MACAddress>
            <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
        </NetworkConnection>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
    </NetworkConnectionSection>
    <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
        <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
        <Enabled>false</Enabled>
        <ChangeSid>false</ChangeSid>
        <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
        <JoinDomainEnabled>false</JoinDomainEnabled>
        <UseOrgSettings>false</UseOrgSettings>
        <AdminPasswordEnabled>true</AdminPasswordEnabled>
        <AdminPasswordAuto>true</AdminPasswordAuto>
        <ResetPasswordRequired>false</ResetPasswordRequired>
        <ComputerName>vm1-001</ComputerName>
        <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
    </GuestCustomizationSection>
    <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
        <ovf:Info>Information about the installed software</ovf:Info>
        <ovf:Product>UnOS</ovf:Product>
    </ovf:ProductSection>
    <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Specifies Runtime info</ovf:Info>
    </RuntimeInfoSection>
    <VAppScopedLocalId>vm1</VAppScopedLocalId>
</Vm>
        instantiated_vm_name_change_request

        INSTANTIATED_VM_NAME_CHANGE_NO_DESCRIPTION_REQUEST = <<-instantiated_vm_name_change_no_description_request.strip()
<Vm xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" needsCustomization="true" deployed="false" status="8" name="#{CHANGED_VM_NAME}" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">
    <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
    <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
    <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
    <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{INSTANTIATED_VM_INSERT_MEDIA_LINK}"/>
    <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
    <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_ATTACH_DISK_LINK}"/>
    <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{INSTANTIATED_VM_DETACH_DISK_LINK}"/>
    <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
    <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-81f65d6c-80b0-4695-a4b1-57ae1f15d795"/>
    <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
    <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
        <ovf:Info>Specifies the operating system installed</ovf:Info>
        <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
        <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
    </ovf:OperatingSystemSection>
    <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false">
        <ovf:Info>Specifies the available VM network connections</ovf:Info>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="none" needsCustomization="true">
            <NetworkConnectionIndex>0</NetworkConnectionIndex>
            <IsConnected>false</IsConnected>
            <MACAddress>00:50:56:02:01:cb</MACAddress>
            <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
        </NetworkConnection>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
    </NetworkConnectionSection>
    <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
        <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
        <Enabled>false</Enabled>
        <ChangeSid>false</ChangeSid>
        <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
        <JoinDomainEnabled>false</JoinDomainEnabled>
        <UseOrgSettings>false</UseOrgSettings>
        <AdminPasswordEnabled>true</AdminPasswordEnabled>
        <AdminPasswordAuto>true</AdminPasswordAuto>
        <ResetPasswordRequired>false</ResetPasswordRequired>
        <ComputerName>vm1-001</ComputerName>
        <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
    </GuestCustomizationSection>
    <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
        <ovf:Info>Information about the installed software</ovf:Info>
        <ovf:Product>UnOS</ovf:Product>
    </ovf:ProductSection>
    <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Specifies Runtime info</ovf:Info>
    </RuntimeInfoSection>
    <VAppScopedLocalId>vm1</VAppScopedLocalId>
</Vm>
        instantiated_vm_name_change_no_description_request

        INSTANTED_VM_CHANGE_TASK_LINK = "#{URL}/api/task/2eea2897-d189-4cf7-9739-758dbfd225d6"

        INSTANTED_VM_CHANGE_TASK_RUNNING = <<-instantiated_vm_change_task_running
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="running" startTime="2011-09-08T10:08:22.903-07:00" operationName="vappUpdateVm" operation="Updating Virtual Machine (#{VM1_ID})" expiryTime="2011-12-07T10:08:22.903-08:00" name="task" id="urn:vcloud:task:2eea2897-d189-4cf7-9739-758dbfd225d6" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTED_VM_CHANGE_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/2eea2897-d189-4cf7-9739-758dbfd225d6/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="" href="#{URL}/api/vApp/vm-619151db-274e-44e9-bcbe-b69bba4ec8c4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vm_change_task_running

        INSTANTED_VM_CHANGE_TASK_SUCCESS = <<-instantiated_vm_change_task_success
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-08T10:08:22.903-07:00" operationName="vappUpdateVm" operation="Updating Virtual Machine (#{VM1_ID})" expiryTime="2011-12-07T10:08:22.903-08:00" name="task" id="urn:vcloud:task:2eea2897-d189-4cf7-9739-758dbfd225d6" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTED_VM_CHANGE_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/2eea2897-d189-4cf7-9739-758dbfd225d6/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="" href="#{URL}/api/vApp/vm-619151db-274e-44e9-bcbe-b69bba4ec8c4"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        instantiated_vm_change_task_success

        INSTANTIATED_VM_HARDWARE_SECTION_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"

        CHANGED_VM_NEW_DISK_SIZE = 350

        INSTANTIATED_VM_ADD_DISK_REQUEST = <<-instantiated_vm_add_disk_request.strip()
<ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System><ovf:Item>
<rasd:HostResource vcloud:capacity="#{CHANGED_VM_NEW_DISK_SIZE}" vcloud:busSubType="lsilogic" vcloud:busType="6"/><rasd:InstanceID/><rasd:ResourceType>17</rasd:ResourceType></ovf:Item>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
        instantiated_vm_add_disk_request

        INSTANTIATED_VM_ADD_DISK_REQUEST_WITH_SERVER_DEFINED_NAMESPACE = <<-instantiated_vm_add_disk_request_server_defined_ns.strip()
<ovf:VirtualHardwareSection xmlns:ns8="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ovf:transport="" ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" ns8:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System><ovf:Item>
<rasd:HostResource ns8:capacity="#{CHANGED_VM_NEW_DISK_SIZE}" ns8:busSubType="lsilogic" ns8:busType="6"/><rasd:InstanceID/><rasd:ResourceType>17</rasd:ResourceType></ovf:Item>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection ns8:primaryNetworkConnection="true" ns8:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource ns8:capacity="200" ns8:busSubType="lsilogic" ns8:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" ns8:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" ns8:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
        instantiated_vm_add_disk_request_server_defined_ns

        RECONFIGURE_VM_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/reconfigureVm"

        RECONFIGURE_VM_REQUEST = <<-reconfigure_vm_request.strip()
<Vm xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" needsCustomization="true" deployed="false" status="8" name="#{CHANGED_VM_NAME}" id="urn:vcloud:vm:#{INSTANTIATED_VM_ID}" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}">
            <Link rel="power:powerOn" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/power/action/powerOn"/>
            <Link rel="deploy" type="application/vnd.vmware.vcloud.deployVAppParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/deploy"/>
            <Link rel="edit" type="application/vnd.vmware.vcloud.vm+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="reconfigureVm" type="application/vnd.vmware.vcloud.vm+xml" name="vm1" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/reconfigureVm"/>
            <Link rel="remove" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}"/>
            <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata"/>
            <Link rel="screen:thumbnail" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/screen"/>
            <Link rel="media:insertMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/insertMedia"/>
            <Link rel="media:ejectMedia" type="application/vnd.vmware.vcloud.mediaInsertOrEjectParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/media/action/ejectMedia"/>
            <Link rel="disk:attach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/disk/action/attach"/>
            <Link rel="disk:detach" type="application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/disk/action/detach"/>
            <Link rel="upgrade" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/action/upgradeHardwareVersion"/>
            <Link rel="up" type="application/vnd.vmware.vcloud.vApp+xml" href="#{URL}/api/vApp/vapp-c032c1a3-21a2-4ac2-8e98-0cc29229e10c"/>
            <Description>#{CHANGED_VM_DESCRIPTION}</Description>
            <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Virtual hardware requirements</ovf:Info>
                <ovf:System>
                    <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
                    <vssd:InstanceID>0</vssd:InstanceID>
                    <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
                    <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
                </ovf:System><ovf:Item>
<rasd:HostResource vcloud:capacity="#{CHANGED_VM_DISK}" vcloud:busSubType="lsilogic" vcloud:busType="6"/><rasd:InstanceID/><rasd:ResourceType>17</rasd:ResourceType></ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>SCSI Controller</rasd:Description>
                    <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
                    <rasd:InstanceID>2</rasd:InstanceID>
                    <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
                    <rasd:ResourceType>6</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:Description>Hard disk</rasd:Description>
                    <rasd:ElementName>Hard disk 1</rasd:ElementName>
                    <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
                    <rasd:InstanceID>2000</rasd:InstanceID>
                    <rasd:Parent>2</rasd:Parent>
                    <rasd:ResourceType>17</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:Address>0</rasd:Address>
                    <rasd:Description>IDE Controller</rasd:Description>
                    <rasd:ElementName>IDE Controller 0</rasd:ElementName>
                    <rasd:InstanceID>3</rasd:InstanceID>
                    <rasd:ResourceType>5</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>CD/DVD Drive</rasd:Description>
                    <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>3000</rasd:InstanceID>
                    <rasd:Parent>3</rasd:Parent>
                    <rasd:ResourceType>15</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item>
                    <rasd:AddressOnParent>0</rasd:AddressOnParent>
                    <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
                    <rasd:Description>Floppy Drive</rasd:Description>
                    <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
                    <rasd:HostResource/>
                    <rasd:InstanceID>8000</rasd:InstanceID>
                    <rasd:ResourceType>14</rasd:ResourceType>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
                    <rasd:Description>Number of Virtual CPUs</rasd:Description>
                    <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
                    <rasd:InstanceID>4</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>3</rasd:ResourceType>
                    <rasd:VirtualQuantity>#{CHANGED_VM_CPU}</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                </ovf:Item>
                <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
                    <rasd:Description>Memory Size</rasd:Description>
                    <rasd:ElementName>32 MB of memory</rasd:ElementName>
                    <rasd:InstanceID>5</rasd:InstanceID>
                    <rasd:Reservation>0</rasd:Reservation>
                    <rasd:ResourceType>4</rasd:ResourceType>
                    <rasd:VirtualQuantity>#{CHANGED_VM_MEMORY}</rasd:VirtualQuantity>
                    <rasd:Weight>0</rasd:Weight>
                    <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                </ovf:Item>
                <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
                <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
                <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
            </ovf:VirtualHardwareSection>
            <ovf:OperatingSystemSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:id="93" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/" vcloud:type="application/vnd.vmware.vcloud.operatingSystemSection+xml" vmw:osType="ubuntuGuest">
                <ovf:Info>Specifies the operating system installed</ovf:Info>
                <ovf:Description>Ubuntu Linux (32-bit)</ovf:Description>
                <Link rel="edit" type="application/vnd.vmware.vcloud.operatingSystemSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/operatingSystemSection/"/>
            </ovf:OperatingSystemSection>
            <NetworkConnectionSection type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/networkConnectionSection/" ovf:required="false">
                <ovf:Info>Specifies the available VM network connections</ovf:Info>
                <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/networkConnectionSection/"/>
            </NetworkConnectionSection>
            <GuestCustomizationSection type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/" ovf:required="false">
                <ovf:Info>Specifies Guest OS Customization Settings</ovf:Info>
                <Enabled>false</Enabled>
                <ChangeSid>false</ChangeSid>
                <VirtualMachineId>#{INSTANTIATED_VM_ID}</VirtualMachineId>
                <JoinDomainEnabled>false</JoinDomainEnabled>
                <UseOrgSettings>false</UseOrgSettings>
                <AdminPasswordEnabled>true</AdminPasswordEnabled>
                <AdminPasswordAuto>true</AdminPasswordAuto>
                <ResetPasswordRequired>false</ResetPasswordRequired>
                <ComputerName>vm1-001</ComputerName>
                <Link rel="edit" type="application/vnd.vmware.vcloud.guestCustomizationSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/guestCustomizationSection/"/>
            </GuestCustomizationSection>
            <ovf:ProductSection ovf:instance="" ovf:class="" ovf:required="true">
                <ovf:Info>Information about the installed software</ovf:Info>
                <ovf:Product>UnOS</ovf:Product>
            </ovf:ProductSection>
            <RuntimeInfoSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/runtimeInfoSection" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
                <ovf:Info>Specifies Runtime info</ovf:Info>
            </RuntimeInfoSection>
            <VAppScopedLocalId>vm1</VAppScopedLocalId>
        </Vm>
        reconfigure_vm_request

        RECONFIGURE_VM_TASK = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2012-07-30T23:04:37.935-07:00" serviceNamespace="com.vmware.vcloud" operationName="vappUpdateVm" operation="Updating Virtual Machine (#{INSTANTIATED_VM_ID})" expiryTime="2012-10-28T23:04:37.935-07:00" cancelRequested="false" name="task" id="urn:vcloud:task:5a1bc92b-1cd0-4286-9ad8-eae948220865" type="application/vnd.vmware.vcloud.task+xml" href="https://10.147.33.83/api/task/5a1bc92b-1cd0-4286-9ad8-eae948220865" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.147.33.83/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/5a1bc92b-1cd0-4286-9ad8-eae948220865/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="" href="#{URL}/api/vApp/#{VM1_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="cfadmin" href="#{URL}/api/admin/user/454f6594-a964-480a-86b5-a3155c876da2"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="cf-org" href="#{URL}/api/org/0b332876-850d-4d7d-8ffd-c5f1749edd64"/>
    <Progress>0</Progress>
    <Details/>
</Task>
        HEREDOC


        UNDEPLOY_PARAMS = <<-undeploy_params.strip()
<ns7:UndeployVAppParams xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns2="http://www.vmware.com/vcloud/v1" xmlns:ns3="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns4="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns5="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:ns6="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" xmlns:ns8="http://schemas.dmtf.org/ovf/environment/1" xmlns:ns9="http://www.vmware.com/vcloud/extension/v1.5" xmlns:ns10="http://www.vmware.com/vcloud/versions"/>
        undeploy_params

        ORG_NETWORK_RESPONSE = <<-org_network_response.strip()
<OrgNetwork xmlns="http://www.vmware.com/vcloud/v1.5" name="#{ORG_NETWORK_NAME}" id="urn:vcloud:network:#{ORG_NETWORK_ID}" type="application/vnd.vmware.vcloud.orgNetwork+xml" href="#{ORG_NETWORK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.org+xml" href="https://10.20.46.172:8443/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="https://10.20.46.172:8443/api/network/#{ORG_NETWORK_ID}/metadata"/>
    <Description/>
    <Configuration>
        <IpScope>
            <IsInherited>true</IsInherited>
            <Gateway>192.168.1.1</Gateway>
            <Netmask>255.255.255.0</Netmask>
            <IpRanges>
                <IpRange>
                    <StartAddress>192.168.1.2</StartAddress>
                    <EndAddress>192.168.1.100</EndAddress>
                </IpRange>
            </IpRanges>
        </IpScope>
        <FenceMode>bridged</FenceMode>
        <RetainNetInfoAcrossDeployments>false</RetainNetInfoAcrossDeployments>
        <SyslogServerSettings/>
    </Configuration>
    <AllowedExternalIpAddresses/>
</OrgNetwork>
        org_network_response

        INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_RESPONSE = <<-instantiated_vapp_network_config_section_response.strip()
<NetworkConfigSection type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    </NetworkConfigSection>
        instantiated_vapp_network_config_section_response

        INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_REQUEST = <<-instantiated_vapp_network_config_add_network_request.strip()
<NetworkConfigSection xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>
        <NetworkConfig networkName="none">
            <Description>This is a special place-holder used for disconnected network interfaces.</Description>
            <Configuration>
                <IpScope>
                    <IsInherited>false</IsInherited>
                    <Gateway>196.254.254.254</Gateway>
                    <Netmask>255.255.0.0</Netmask>
                    <Dns1>196.254.254.254</Dns1>
                </IpScope>
                <FenceMode>isolated</FenceMode>
            </Configuration>
            <IsDeployed>false</IsDeployed>
        </NetworkConfig>
    <NetworkConfig networkName="#{VAPP_NETWORK_NAME}">
  <Description/>
  <Configuration>
    <IpScopes>
      <IpScope>
        <IsInherited>true</IsInherited>
        <Gateway>192.168.1.1</Gateway>
        <Netmask>255.255.255.0</Netmask>
        <IpRanges>
          <IpRange>
            <StartAddress>192.168.1.2</StartAddress>
            <EndAddress>192.168.1.100</EndAddress>
          </IpRange>
        </IpRanges>
      </IpScope>
    </IpScopes>
    <ParentNetwork type="application/vnd.vmware.vcloud.network+xml" name="#{ORG_NETWORK_NAME}" href="#{ORG_NETWORK_LINK}"/>
    <FenceMode>bridged</FenceMode>
  </Configuration>
</NetworkConfig></NetworkConfigSection>
        instantiated_vapp_network_config_add_network_request

        INSTANTED_VAPP_NETWORK_CONFIG_REMOVE_NETWORK_REQUEST =<<-HEREDOC.strip()
    <NetworkConfigSection xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}" ovf:required="false">
        <ovf:Info>The configuration parameters for logical networks</ovf:Info>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConfigSection+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK}"/>


    </NetworkConfigSection>
        HEREDOC



        INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_TASK_LINK = "#{URL}/api/task/23e5280c-2a91-4a8c-a136-9822ba33f34f"

        INSTANTIATED_VAPP_NETWORK_CONFIG_MODIFY_NETWORK_TASK_SUCCESS = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-14T14:07:14.185-07:00" operationName="vdcUpdateVappNetworkSection" operation="Updating Virtual Application #{VAPP_NAME}(#{VAPP_ID})" expiryTime="2011-12-13T14:07:14.185-08:00" name="task" id="urn:vcloud:task:23e5280c-2a91-4a8c-a136-9822ba33f34f" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/23e5280c-2a91-4a8c-a136-9822ba33f34f/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="test17_3_10" href="#{URL}/api/vApp/vapp-53599c71-4d39-49ad-878f-45e43ecaa7c8"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        HEREDOC

        INSTANTIATED_VAPP_NETWORK_CONFIG_MODIFY_NETWORK_TASK_ERROR = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="error" startTime="2011-09-14T14:07:14.185-07:00" operationName="vdcUpdateVappNetworkSection" operation="Updating Virtual Application #{VAPP_NAME}(#{VAPP_ID})" expiryTime="2011-12-13T14:07:14.185-08:00" name="task" id="urn:vcloud:task:23e5280c-2a91-4a8c-a136-9822ba33f34f" type="application/vnd.vmware.vcloud.task+xml" href="#{INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/23e5280c-2a91-4a8c-a136-9822ba33f34f/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vApp+xml" name="test17_3_10" href="#{URL}/api/vApp/vapp-53599c71-4d39-49ad-878f-45e43ecaa7c8"/>
    <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        HEREDOC

        NEW_NIC_INDEX = '1'

        NEW_NIC_ADDRESSING_MODE = 'POOL'

        INSTANTIATED_VM_ADD_NIC_REQUEST = <<-HEREDOC.strip()
  <ovf:VirtualHardwareSection xmlns:vcloud="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ovf:transport="" vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" vcloud:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System><ovf:Item>
<rasd:AddressOnParent>#{NEW_NIC_INDEX}</rasd:AddressOnParent><rasd:Connection vcloud:ipAddressingMode="#{NEW_NIC_ADDRESSING_MODE}" vcloud:ipAddress="" vcloud:primaryNetworkConnection="false">#{ORG_NETWORK_NAME}</rasd:Connection><rasd:InstanceID/><rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType><rasd:ResourceType>10</rasd:ResourceType></ovf:Item>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection vcloud:primaryNetworkConnection="true" vcloud:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource vcloud:capacity="200" vcloud:busSubType="lsilogic" vcloud:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item vcloud:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" vcloud:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
        HEREDOC

        INSTANTIATED_VM_ADD_NIC_REQUEST_WITH_SERVER_DEFINED_NAMESPACE  = <<-instantiated_vm_add_nic_request_with_server_defined_namespace.strip()
  <ovf:VirtualHardwareSection xmlns:ns8="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ovf:transport="" ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/" ns8:type="application/vnd.vmware.vcloud.virtualHardwareSection+xml">
        <ovf:Info>Virtual hardware requirements</ovf:Info>
        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>vm1</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-04</vssd:VirtualSystemType>
        </ovf:System><ovf:Item>
<rasd:AddressOnParent>#{NEW_NIC_INDEX}</rasd:AddressOnParent><rasd:Connection ns8:ipAddressingMode="#{NEW_NIC_ADDRESSING_MODE}" ns8:ipAddress="" ns8:primaryNetworkConnection="false">#{ORG_NETWORK_NAME}</rasd:Connection><rasd:InstanceID/><rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType><rasd:ResourceType>10</rasd:ResourceType></ovf:Item>
        <ovf:Item>
            <rasd:Address>00:50:56:02:01:cb</rasd:Address>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Connection ns8:primaryNetworkConnection="true" ns8:ipAddressingMode="NONE">none</rasd:Connection>
            <rasd:Description>VMXNET3 ethernet adapter</rasd:Description>
            <rasd:ElementName>Network adapter 0</rasd:ElementName>
            <rasd:InstanceID>1</rasd:InstanceID>
            <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
            <rasd:ResourceType>10</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>SCSI Controller</rasd:Description>
            <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
            <rasd:InstanceID>#{SCSI_CONTROLLER_ID}</rasd:InstanceID>
            <rasd:ResourceSubType>lsilogic</rasd:ResourceSubType>
            <rasd:ResourceType>6</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:Description>Hard disk</rasd:Description>
            <rasd:ElementName>Hard disk 1</rasd:ElementName>
            <rasd:HostResource ns8:capacity="200" ns8:busSubType="lsilogic" ns8:busType="6"/>
            <rasd:InstanceID>2000</rasd:InstanceID>
            <rasd:Parent>2</rasd:Parent>
            <rasd:ResourceType>17</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:Address>0</rasd:Address>
            <rasd:Description>IDE Controller</rasd:Description>
            <rasd:ElementName>IDE Controller 0</rasd:ElementName>
            <rasd:InstanceID>3</rasd:InstanceID>
            <rasd:ResourceType>5</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>CD/DVD Drive</rasd:Description>
            <rasd:ElementName>CD/DVD Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>3000</rasd:InstanceID>
            <rasd:Parent>3</rasd:Parent>
            <rasd:ResourceType>15</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item>
            <rasd:AddressOnParent>0</rasd:AddressOnParent>
            <rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>
            <rasd:Description>Floppy Drive</rasd:Description>
            <rasd:ElementName>Floppy Drive 1</rasd:ElementName>
            <rasd:HostResource/>
            <rasd:InstanceID>8000</rasd:InstanceID>
            <rasd:ResourceType>14</rasd:ResourceType>
        </ovf:Item>
        <ovf:Item ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu" ns8:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
            <rasd:Description>Number of Virtual CPUs</rasd:Description>
            <rasd:ElementName>1 virtual CPU(s)</rasd:ElementName>
            <rasd:InstanceID>4</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>3</rasd:ResourceType>
            <rasd:VirtualQuantity>1</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        </ovf:Item>
        <ovf:Item ns8:href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory" ns8:type="application/vnd.vmware.vcloud.rasdItem+xml">
            <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
            <rasd:Description>Memory Size</rasd:Description>
            <rasd:ElementName>32 MB of memory</rasd:ElementName>
            <rasd:InstanceID>5</rasd:InstanceID>
            <rasd:Reservation>0</rasd:Reservation>
            <rasd:ResourceType>4</rasd:ResourceType>
            <rasd:VirtualQuantity>32</rasd:VirtualQuantity>
            <rasd:Weight>0</rasd:Weight>
            <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        </ovf:Item>
        <Link rel="edit" type="application/vnd.vmware.vcloud.virtualHardwareSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/cpu"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItem+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/memory"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/disks"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/media"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/networkCards"/>
        <Link rel="down" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
        <Link rel="edit" type="application/vnd.vmware.vcloud.rasdItemsList+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/virtualHardwareSection/serialPorts"/>
    </ovf:VirtualHardwareSection>
        instantiated_vm_add_nic_request_with_server_defined_namespace

        INSTANTIATED_VM_NETWORK_SECTION_RESPONSE =<<-HEREDOC.strip()
    <NetworkConnectionSection xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}" ovf:required="false" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
        <ovf:Info>Specifies the available VM network connections</ovf:Info>
        <PrimaryNetworkConnectionIndex>0</PrimaryNetworkConnectionIndex>
        <NetworkConnection network="none" needsCustomization="true">
            <NetworkConnectionIndex>0</NetworkConnectionIndex>
            <IsConnected>false</IsConnected>
            <MACAddress>00:50:56:02:01:cb</MACAddress>
            <IpAddressAllocationMode>NONE</IpAddressAllocationMode>
        </NetworkConnection>
        <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
    </NetworkConnectionSection>
        HEREDOC

        INSTANTIATED_VM_REMOVE_NIC_REQUEST =<<-HEREDOC.strip()
<NetworkConnectionSection xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/networkConnectionSection/" ovf:required="false">
  <ovf:Info>Specifies the available VM network connections</ovf:Info>
  <Link rel="edit" type="application/vnd.vmware.vcloud.networkConnectionSection+xml" href="#{INSTANTIATED_VM_NETWORK_SECTION_LINK}"/>
</NetworkConnectionSection>
        HEREDOC

        MEDIA_ID  = '35aa7d6c-0794-456b-bbd1-021bb75e2af7'

        # bogus content
        MEDIA_CONTENT = "35aa7d6c-0794-456b-bbd1-021bb75e2af7"

        MEDIA_LINK = "#{URL}/api/media/#{MEDIA_ID}"

        MEDIA_DELETE_TASK_ID = "ddaa7d6c-0794-456b-bbd1-021bb75e2abc"

        MEDIA_DELETE_TASK_LINK = "#{URL}/api/task/#{EXISTING_MEDIA_DELETE_TASK_ID}"

        MEDIA_DELETE_TASK_DONE = <<-HEREDOC.strip()
        <Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-22T13:12:32.551-07:00" operationName="vdcDeleteMedia" operation="Deleting Media File (4ed2b53a-dbdd-4761-8036-fa67920749c5)" expiryTime="2011-12-21T13:12:32.551-08:00" name="task" id="urn:vcloud:task:#{MEDIA_DELETE_TASK_ID}" type="application/vnd.vmware.vcloud.task+xml" href="#{MEDIA_DELETE_TASK_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
            <Link rel="task:cancel" href="#{URL}/api/task/#{MEDIA_DELETE_TASK_ID}/action/cancel"/>
            <Owner type="application/vnd.vmware.vcloud.media+xml" name="" href="#{MEDIA_LINK}"/>
            <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
            <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
        </Task>
        HEREDOC

        MEDIA_ISO_LINK  = "#{URL}/transfer/1ff5509a-4cd8-4005-aa14-f009578651e9/file"

        MEDIA_UPLOAD_REQUEST = <<-HEREDOC.strip()
<ns7:Media xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" size="833536" name="#{MEDIA_NAME}" imageType="iso">
</ns7:Media>
        HEREDOC

        MEDIA_UPLOAD_PENDING_RESPONSE =<<-HEREDOC.strip()
<?xml version="1.0" encoding="UTF-8"?>
<Media xmlns="http://www.vmware.com/vcloud/v1.5" size="833536" imageType="iso" status="0" name="#{MEDIA_NAME}" id="urn:vcloud:media:#{MEDIA_ID}" type="application/vnd.vmware.vcloud.media+xml" href="#{MEDIA_LINK}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{VDC_LINK}"/>
    <Link rel="remove" href="#{URL}/api/media/#{MEDIA_ID}"/>
    <Files>
        <File size="833536" bytesTransferred="0" name="file">
            <Link rel="upload:default" href="#{MEDIA_ISO_LINK}"/>
        </File>
    </Files>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    </Owner>
</Media>
        HEREDOC

        MEDIA_ADD_TO_CATALOG_REQUEST = <<-HEREDOC.strip()
<ns7:CatalogItem xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns2="http://www.vmware.com/vcloud/v1" xmlns:ns3="http://schemas.dmtf.org/ovf/envelope/1" xmlns:ns4="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:ns5="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:ns6="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ns7="http://www.vmware.com/vcloud/v1.5" xmlns:ns8="http://schemas.dmtf.org/ovf/environment/1" xmlns:ns9="http://www.vmware.com/vcloud/extension/v1.5" xmlns:ns10="http://www.vmware.com/vcloud/versions" name="#{MEDIA_NAME}" id="" type="" href="">
  <ns7:Description/>
  <ns7:Tasks/>
  <ns7:Entity name="#{MEDIA_NAME}" id="urn:vcloud:media:#{MEDIA_ID}" href="#{URL}/api/media/#{MEDIA_ID}" type="application/vnd.vmware.vcloud.media+xml"/>
</ns7:CatalogItem>
        HEREDOC

        MEDIA_CATALOG_ITEM_ID = "a0185003-1a65-4fe4-9fe1-08e81ce26ef6"

        MEDIA_CATALOG_ITEM_DELETE_LINK = "#{URL}/api/catalogItem/#{MEDIA_CATALOG_ITEM_ID}"

        MEDIA_ADD_TO_CATALOG_RESPONSE = <<-HEREDOC.strip()
<CatalogItem xmlns="http://www.vmware.com/vcloud/v1.5" name="#{MEDIA_NAME}" id="urn:vcloud:catalogitem:#{MEDIA_CATALOG_ITEM_ID}" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/#{MEDIA_CATALOG_ITEM_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.catalog+xml" href="#{URL}/api/catalog/cfab326c-ab71-445c-bc0b-abf15239de8b"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/catalogItem/#{MEDIA_CATALOG_ITEM_ID}/metadata"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{URL}/api/catalogItem/#{MEDIA_CATALOG_ITEM_ID}"/>
    <Link rel="remove" href="#{MEDIA_CATALOG_ITEM_DELETE_LINK}"/>
    <Description/>
    <Entity type="application/vnd.vmware.vcloud.media+xml" name="#{MEDIA_NAME}" href="#{MEDIA_LINK}"/>
</CatalogItem>
        HEREDOC

        METADATA_VALUE = 'test123'

        METADATA_KEY = 'test_key'

        METADATA_SET_LINK = "#{URL}/api/vApp/vm-#{INSTANTIATED_VM_ID}/metadata/#{METADATA_KEY}"

        METADATA_SET_REQUEST = <<-HEREDOC.strip()
<ns7:MetadataValue xmlns="http://www.vmware.com/vcloud/extension/v1" xmlns:ns7="http://www.vmware.com/vcloud/v1.5">
  <ns7:Value>#{METADATA_VALUE}</ns7:Value>
</ns7:MetadataValue>
        HEREDOC

        METADATA_SET_TASK_DONE = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-09-26T16:12:12.143-07:00" operationName="metadataUpdate" operation="Updating metadata for Virtual Machine (#{INSTANTIATED_VM_ID})" expiryTime="2011-12-25T16:12:12.143-08:00" name="task" id="urn:vcloud:task:424a7342-5f47-49d8-9879-e7871dfa9d04" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/424a7342-5f47-49d8-9879-e7871dfa9d04" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/424a7342-5f47-49d8-9879-e7871dfa9d04/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="" href="#{URL}/api/vApp/vm-4cad7e64-b201-4042-8892-8dfa50ed5516"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/42cbe98d-48da-4f5d-944e-596843a9fcb5"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/b689c06e-1de0-4fd1-a5a3-050c479546ac"/>
</Task>
        HEREDOC

        INDY_DISK_CREATE_REQUEST = <<-HEREDOC.strip()
<DiskCreateParams xmlns="http://www.vmware.com/vcloud/v1.5">
  <Disk name="#{INDY_DISK_NAME}" size="#{INDY_DISK_SIZE * 1024 * 1024}" busType="6" busSubType="lsilogic">
  </Disk>
</DiskCreateParams>
        HEREDOC

        INDY_DISK_CREATE_RESPONSE = <<-HEREDOC.strip()
<Disk xmlns="http://www.vmware.com/vcloud/v1.5" size="0" busType="6" busSubType="lsilogic" status="0" name="test5" id="urn:vcloud:disk:#{INDY_DISK_ID}" type="application/vnd.vmware.vcloud.disk+xml" href="#{URL}/api/disk#{INDY_DISK_ID}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/7152945d-1041-4c08-9423-23b32c9be1f4"/>
    <Link rel="remove" href="#{INDY_DISK_URL}"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.disk+xml" href="#{URL}/api/disk/#{INDY_DISK_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/disk/#{INDY_DISK_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/disk/#{INDY_DISK_ID}/metadata"/>
    <Tasks>
        <Task status="success" startTime="2011-10-05T14:23:03.138-07:00" operationName="vdcCreateDisk" operation="Creating Disk test5(#{INDY_DISK_ID})" expiryTime="2012-01-03T14:23:03.138-08:00" name="task" id="urn:vcloud:task:3cdaeaa1-6dd3-439d-95d5-a9208e0c5dba" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/3cdaeaa1-6dd3-439d-95d5-a9208e0c5dba">
            <Link rel="task:cancel" href="#{URL}/api/task/3cdaeaa1-6dd3-439d-95d5-a9208e0c5dba/action/cancel"/>
            <Owner type="application/vnd.vmware.vcloud.disk+xml" name="test5" href="#{URL}/api/disk/#{INDY_DISK_ID}"/>
            <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/f37afbc4-77a9-4ca6-93b3-d1607f82b329"/>
            <Organization type="application/vnd.vmware.vcloud.org+xml" name="vcap" href="#{URL}/api/org/7b8a9ff3-1f41-48ae-8eb2-b91140adc010"/>
        </Task>
    </Tasks>
    <StorageClass type="application/vnd.vmware.vcloud.vdcStorageClass+xml" name="*" href="#{URL}/api/vdcStorageClass/8fe92f5a-efb7-456e-af78-54a120c9cf8f"/>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/61150fcf-1eda-4cd3-a8a5-e51717a2806d"/>
    </Owner>
</Disk>
        HEREDOC

        INDY_DISK_CREATE_ERROR = <<-HEREDOC.strip()
<Error xmlns="http://www.vmware.com/vcloud/v1.5" minorErrorCode="BAD_REQUEST" message="The requested operation will exceed the vDC's storage quota." majorErrorCode="400" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd"></Error>
        HEREDOC

        INDY_DISK_RESPONSE = <<-HEREDOC.strip()
<Disk xmlns="http://www.vmware.com/vcloud/v1.5" size="#{INDY_DISK_SIZE * 1000000}" busType="6" busSubType="lsilogic" status="1" name="#{INDY_DISK_NAME}" id="urn:vcloud:disk:#{INDY_DISK_ID}" type="application/vnd.vmware.vcloud.disk+xml" href="#{INDY_DISK_URL}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="up" type="application/vnd.vmware.vcloud.vdc+xml" href="#{URL}/api/vdc/7152945d-1041-4c08-9423-23b32c9be1f4"/>
    <Link rel="remove" href="#{URL}/api/disk/#{INDY_DISK_ID}"/>
    <Link rel="edit" type="application/vnd.vmware.vcloud.disk+xml" href="#{URL}/api/disk/#{INDY_DISK_ID}"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.owner+xml" href="#{URL}/api/disk/#{INDY_DISK_ID}/owner"/>
    <Link rel="down" type="application/vnd.vmware.vcloud.metadata+xml" href="#{URL}/api/disk/#{INDY_DISK_ID}/metadata"/>
    <StorageClass type="application/vnd.vmware.vcloud.vdcStorageClass+xml" name="*" href="#{URL}/api/vdcStorageClass/8fe92f5a-efb7-456e-af78-54a120c9cf8f"/>
    <Owner type="application/vnd.vmware.vcloud.owner+xml">
        <User type="application/vnd.vmware.admin.user+xml" name="vcap" href="#{URL}/api/admin/user/61150fcf-1eda-4cd3-a8a5-e51717a2806d"/>
    </Owner>
</Disk>
        HEREDOC

        INDY_DISK_ADDRESS_ON_PARENT = "1"

        INDY_DISK_ATTACH_REQUEST = <<-HEREDOC.strip()
<DiskAttachOrDetachParams xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:vcloud="http://www.vmware.com/vcloud/v1.5">
  <Disk type="application/vnd.vmware.vcloud.disk+xml" href="#{INDY_DISK_URL}"> </Disk>
</DiskAttachOrDetachParams>
        HEREDOC

        INDY_DISK_ATTACH_TASK = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-10-05T14:23:14.016-07:00" operationName="vappAttachDisk" operation="Attaching Disk to Virtual Machine vm1(97050e89-acf5-4599-9564-46fa762e82b8)" expiryTime="2012-01-03T14:23:14.016-08:00" name="task" id="urn:vcloud:task:440545e8-9ee7-4c67-9d2e-8881246a084c" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/440545e8-9ee7-4c67-9d2e-8881246a084c" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/440545e8-9ee7-4c67-9d2e-8881246a084c/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{URL}/api/vApp/vm-#{VM1_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/f37afbc4-77a9-4ca6-93b3-d1607f82b329"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/7b8a9ff3-1f41-48ae-8eb2-b91140adc010"/>
</Task>
        HEREDOC

        INDY_DISK_ATTACH_TASK_ERROR = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="error" startTime="2011-10-05T14:23:14.016-07:00" operationName="vappAttachDisk" operation="Attaching Disk to Virtual Machine vm1(97050e89-acf5-4599-9564-46fa762e82b8)" expiryTime="2012-01-03T14:23:14.016-08:00" name="task" id="urn:vcloud:task:440545e8-9ee7-4c67-9d2e-8881246a084c" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/440545e8-9ee7-4c67-9d2e-8881246a084c" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/440545e8-9ee7-4c67-9d2e-8881246a084c/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{URL}/api/vApp/vm-#{VM1_ID}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/f37afbc4-77a9-4ca6-93b3-d1607f82b329"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/7b8a9ff3-1f41-48ae-8eb2-b91140adc010"/>
</Task>
        HEREDOC

        INDY_DISK_DETACH_REQUEST = <<-HEREDOC.strip()
<DiskAttachOrDetachParams xmlns="http://www.vmware.com/vcloud/v1.5" xmlns:vcloud="http://www.vmware.com/vcloud/v1.5">
  <Disk type="application/vnd.vmware.vcloud.disk+xml" href="#{INDY_DISK_URL}"> </Disk>
</DiskAttachOrDetachParams>
        HEREDOC

        INDY_DISK_DETACH_TASK = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-10-05T14:23:24.729-07:00" operationName="vappDetachDisk" operation="Detaching Disk from Virtual Machine vm1(97050e89-acf5-4599-9564-46fa762e82b8)" expiryTime="2012-01-03T14:23:24.729-08:00" name="task" id="urn:vcloud:task:b4b83acd-7d2b-49be-a8ae-d7485e0f945c" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/b4b83acd-7d2b-49be-a8ae-d7485e0f945c" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/b4b83acd-7d2b-49be-a8ae-d7485e0f945c/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.vm+xml" name="#{VM_NAME}" href="#{URL}/api/vApp/vm-97050e89-acf5-4599-9564-46fa762e82b8"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/f37afbc4-77a9-4ca6-93b3-d1607f82b329"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/7b8a9ff3-1f41-48ae-8eb2-b91140adc010"/>
</Task>
        HEREDOC

        INDY_DISK_DELETE_TASK = <<-HEREDOC.strip()
<Task xmlns="http://www.vmware.com/vcloud/v1.5" status="success" startTime="2011-10-05T14:23:35.027-07:00" operationName="vdcDeleteDisk" operation="Deleting Disk (#{INDY_DISK_ID})" expiryTime="2012-01-03T14:23:35.027-08:00" name="task" id="urn:vcloud:task:0e83b4d9-2f24-4ec1-9dd3-7d9c20936cbf" type="application/vnd.vmware.vcloud.task+xml" href="#{URL}/api/task/0e83b4d9-2f24-4ec1-9dd3-7d9c20936cbf" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.20.46.172/api/v1.5/schema/master.xsd">
    <Link rel="task:cancel" href="#{URL}/api/task/0e83b4d9-2f24-4ec1-9dd3-7d9c20936cbf/action/cancel"/>
    <Owner type="application/vnd.vmware.vcloud.disk+xml" name="" href="#{INDY_DISK_URL}"/>
    <User type="application/vnd.vmware.admin.user+xml" name="#{USERNAME}" href="#{URL}/api/admin/user/f37afbc4-77a9-4ca6-93b3-d1607f82b329"/>
    <Organization type="application/vnd.vmware.vcloud.org+xml" name="#{ORGANIZATION}" href="#{URL}/api/org/7b8a9ff3-1f41-48ae-8eb2-b91140adc010"/>
</Task>
        HEREDOC

        EXISTING_VAPP_RESOLVER_RESPONSE = <<-HEREDOC.strip()
<Entity xmlns="http://www.vmware.com/vcloud/v1.5" name="#{EXISTING_VAPP_URN}" id="#{EXISTING_VAPP_URN}" type="application/vnd.vmware.vcloud.entity+xml" href="#{EXISTING_VAPP_RESOLVER_URL}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.147.49.240/api/v1.5/schema/master.xsd">
    <Link rel="alternate" type="application/vnd.vmware.vcloud.vApp+xml" href="#{EXISTING_VAPP_LINK}"/>
</Entity>
        HEREDOC

        EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_RESPONSE = <<-HEREDOC.strip()
<Entity xmlns="http://www.vmware.com/vcloud/v1.5" name="#{EXISTING_VAPP_TEMPLATE_CATALOG_URN}" id="#{EXISTING_VAPP_TEMPLATE_CATALOG_URN}" type="application/vnd.vmware.vcloud.entity+xml" href="#{EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_URL}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.147.49.240/api/v1.5/schema/master.xsd">
    <Link rel="alternate" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_LINK}"/>
</Entity>
        HEREDOC

        VAPP_TEMPLATE_CATALOG_RESOLVER_RESPONSE = <<-HEREDOC.strip()
<Entity xmlns="http://www.vmware.com/vcloud/v1.5" name="#{VAPP_TEMPLATE_CATALOG_URN}" id="#{VAPP_TEMPLATE_CATALOG_URN}" type="application/vnd.vmware.vcloud.entity+xml" href="#{VAPP_TEMPLATE_CATALOG_RESOLVER_URL}" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.vmware.com/vcloud/v1.5 http://10.147.49.240/api/v1.5/schema/master.xsd">
    <Link rel="alternate" type="application/vnd.vmware.vcloud.catalogItem+xml" href="#{VAPP_TEMPLATE_CATALOG_ITEM_LINK}"/>
</Entity>
        HEREDOC

      end
    end
end
