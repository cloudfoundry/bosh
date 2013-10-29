require 'spec_helper'

describe 'Stemcell with Go Agent' do
  describe 'installed by bosh_go_agent' do
    describe file('/var/vcap/bosh/bin/bosh-agent') do
      it { should be_file }
      it { should be_executable }
    end
  end
end