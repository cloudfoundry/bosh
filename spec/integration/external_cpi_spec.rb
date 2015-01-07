require 'spec_helper'

describe 'external CPIs', type: :integration do
  with_reset_sandbox_before_each

  describe 'director configured to use external dummy CPI' do
    before do
      current_sandbox.external_cpi_enabled = true
      current_sandbox.restart_director
      deploy_simple
    end

    after do
      current_sandbox.external_cpi_enabled = false
      current_sandbox.restart_director
    end

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
