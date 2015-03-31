require 'spec_helper'

describe 'RHEL 7 stemcell', stemcell_image: true do

  it_behaves_like 'All Stemcells'
  it_behaves_like 'a CentOS 7 or RHEL 7 stemcell'

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('centos') }
    end
  end
end
