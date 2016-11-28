require 'spec_helper'

describe 'Photonos 1 stemcell', stemcell_image: true do

  it_behaves_like 'All Stemcells'
  it_behaves_like 'udf module is disabled'
  
  context 'installed by system_parameters' do
    describe file('/etc/photon-release') do
      it { should be_file }
    end
  end
end
