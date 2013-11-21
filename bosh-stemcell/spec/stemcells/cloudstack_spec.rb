require 'spec_helper'

describe 'CloudStack Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('cloudstack') }
    end
  end
end
