require 'spec_helper'

describe 'Ubuntu 14.04 stemcell.tgz', stemcell_tgz: true do
  
  context 'installed by bosh_dpkg_list stage' do
    describe file("#{ENV['STEMCELL_TGZ_WORKDIR']}/stemcell_dpkg_l.txt") do
      it { should be_file }
      it { should contain 'Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend' }
      it { should contain 'ubuntu-minimal' }
    end
  end
  
end
