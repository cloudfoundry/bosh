require 'spec_helper'

describe 'Ubuntu Lucid stemcell.tgz', stemcell_tgz: true do
  
  context 'installed by bosh_dpkg_list stage' do
    describe file("#{ENV['STEMCELL_TGZ_WORKDIR']}/stemcell_dpkg_l.txt") do
      it { should be_file }
      it { should contain 'Status=Not/Inst/Cfg-files/Unpacked/Failed-cfg/Half-inst/trig-aWait/Trig-pend' }
      it { should contain 'ubuntu-minimal' }
    end
  end
  
end
