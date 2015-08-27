require 'spec_helper'

describe 'Photon 1 stemcell', stemcell_image: true do

  it_behaves_like 'All Stemcells'
  
  context 'installed by system_parameters' do
    describe file('/etc/photon-release') do
      it { should be_file }
    end
  end
end
