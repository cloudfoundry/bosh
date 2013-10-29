require 'spec_helper'

describe 'Stemcell with Ruby Agent' do
  describe 'installed by bosh_ruby' do
    describe command('/var/vcap/bosh/bin/ruby -r yaml -e "Psych::SyntaxError"') do
      it { should return_exit_status(0) }
    end
  end

  describe 'installed by bosh_agent' do
    describe command('/var/vcap/bosh/bin/ruby -r bosh_agent -e "Bosh::Agent"') do
      it { should return_exit_status(0) }
    end
  end

  context 'installed by bosh_micro' do
    describe file('/var/vcap/micro/apply_spec.yml') do
      it { should be_file }
      it { should contain 'deployment: micro' }
      it { should contain 'powerdns' }
    end

    describe file('/var/vcap/micro_bosh/data/cache') do
      it { should be_a_directory }
    end
  end
end
