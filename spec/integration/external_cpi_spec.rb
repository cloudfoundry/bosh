require 'spec_helper'

describe 'external CPIs', type: :integration do
  with_reset_sandbox_before_each

  it 'deploys using the external CPI' do
    current_sandbox.external_cpi_enabled = true
    current_sandbox.reconfigure_director
    current_sandbox.reconfigure_workers

    expect(deploy_simple).to match /Task (\d+) done/

    deploy_results = bosh_runner.run('task last --debug')
    expect(deploy_results).to include('External CPI sending request')
  end
end
