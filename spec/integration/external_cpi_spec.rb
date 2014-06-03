require 'spec_helper'

describe 'external CPIs', type: :integration do
  describe 'director configured to use external dummy CPI' do
    with_reset_sandbox_before_all

    before(:all) do
      current_sandbox.external_cpi_enabled = true
      current_sandbox.reconfigure_director
      current_sandbox.reconfigure_workers
    end

    after(:all) do
      current_sandbox.external_cpi_enabled = false
      current_sandbox.reconfigure_director
      current_sandbox.reconfigure_workers
    end

    before(:all) { deploy_simple }

    it 'deploys using the external CPI' do
      deploy_results = bosh_runner.run('task last --debug')
      expect(deploy_results).to include('External CPI sending request')
    end

    it 'saves external CPI logs' do
      deploy_results = bosh_runner.run('task last --cpi')
      expect(deploy_results).to include('Dummy: create_vm')
    end
  end
end
