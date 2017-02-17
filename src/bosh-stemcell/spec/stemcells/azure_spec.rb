require 'spec_helper'

describe 'Azure Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('azure') }
    end
  end

  context 'installed by bosh_disable_password_authentication' do
    describe 'disallows password authentication' do
      subject { file('/etc/ssh/sshd_config') }
      it { should contain /^PasswordAuthentication no$/ }
    end
  end

  context 'udf module should be enabled' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should_not contain 'install udf /bin/true' }
    end
  end

  context 'installed by bosh_azure_agent_settings', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
    exclude_on_softlayer: true,
  } do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"Type": "File"') }
      it { should contain('"MetaDataPath": ""') }
      it { should contain('"UserDataPath": "/var/lib/waagent/CustomData"') }
      it { should contain('"SettingsPath": "/var/lib/waagent/CustomData"') }
      it { should contain('"UseServerName": true') }
      it { should contain('"UseRegistry": true') }
      it { should contain('"DevicePathResolutionType": "scsi"') }
      it { should contain('"CreatePartitionIfNoEphemeralDisk": true') }
    end
  end

  context 'installed by the system_azure_network', {
    exclude_on_aws: true,
    exclude_on_google: true,
    exclude_on_vcloud: true,
    exclude_on_vsphere: true,
    exclude_on_warden: true,
    exclude_on_openstack: true,
  } do
    case ENV['OS_NAME']
      when 'ubuntu'
        describe file('/etc/network/interfaces') do
          it { should be_file }
          it { should contain 'auto eth0' }
          it { should contain 'iface eth0 inet dhcp' }
        end

      when 'centos'
        describe file('/etc/sysconfig/network') do
          it { should be_file }
          it { should contain 'NETWORKING=yes' }
          it { should contain 'NETWORKING_IPV6=no' }
          it { should contain 'HOSTNAME=bosh-stemcell' }
          it { should contain 'NOZEROCONF=yes' }
        end
        describe file('/etc/sysconfig/network-scripts/ifcfg-eth0') do
          it { should be_file }
          it { should contain 'DEVICE=eth0' }
          it { should contain 'BOOTPROTO=dhcp' }
          it { should contain 'ONBOOT=on' }
          it { should contain 'TYPE="Ethernet"' }
          it { should contain 'NM_CONTROLLED=no' }
        end
      end
  end
end
