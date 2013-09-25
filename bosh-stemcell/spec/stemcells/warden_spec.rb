require 'spec_helper'

describe 'Warden Stemcell' do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('warden') }
    end
  end
end
