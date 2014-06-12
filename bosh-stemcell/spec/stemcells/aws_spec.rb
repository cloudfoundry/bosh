require 'spec_helper'

describe 'AWS Stemcell', stemcell_image: true do
  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/infrastructure') do
      it { should contain('aws') }
    end
  end
end
