require 'spec_helper'

describe 'OpenStack Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('openstack') }
    end
  end

  context 'installed by bosh_openstack_agent_settings' do
    describe file('/var/vcap/bosh/agent.json') do
      it { should be_valid_json_file }
      it { should contain('"CreatePartitionIfNoEphemeralDisk": true') }
    end
  end
end
