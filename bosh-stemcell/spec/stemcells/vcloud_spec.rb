require 'spec_helper'

describe 'vCloud Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('vcloud') }
    end
  end
end
