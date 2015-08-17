require 'spec_helper'

describe 'Photon 1 OS image', os_image: true do
  it_behaves_like 'every OS image'
  it_behaves_like 'a systemd-based OS image'

  context 'installed by base_rhel' do
        describe file('/etc/photon-release') do
      it { should be_file }
    end

    describe file('/etc/locale.conf') do
      it { should be_file }
      it { should contain 'en_US.UTF-8' }
    end
  end
end

  
