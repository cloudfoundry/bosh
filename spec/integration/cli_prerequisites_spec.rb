require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage deployment prerequisites' do
  include IntegrationExampleGroup

  describe 'deployment prerequisites' do
    it 'requires target and login' do
      expect(run_bosh('deploy', :failure_expected => true)).to match(/Please choose target first/)
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      expect(run_bosh('deploy', :failure_expected => true)).to match(/Please log in first/)
    end

    it 'requires deployment to be chosen' do
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')
      expect(run_bosh('deploy', :failure_expected => true)).to match(/Please choose deployment first/)
    end
  end
end
