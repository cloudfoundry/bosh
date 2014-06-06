require 'spec_helper'

describe 'OpenStack Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('openstack') }
    end
  end
end
