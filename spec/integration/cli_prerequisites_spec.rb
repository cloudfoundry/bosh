require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage deployment prerequisites' do
  include IntegrationExampleGroup

  describe 'deployment prerequisites' do
    it 'requires target and login' do
      run_bosh('deploy').should =~ /Please choose target first/
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('deploy').should =~ /Please log in first/
    end

    it 'requires deployment to be chosen' do
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')
      run_bosh('deploy').should =~ /Please choose deployment first/
    end
  end
end
