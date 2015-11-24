require 'spec_helper'

describe 'start job', type: :integration do
  with_reset_sandbox_before_each

  it 'starts a deployment' do
    deploy_from_scratch
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
    bosh_runner.run('stop')
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['stopped'])
    expect(bosh_runner.run('start')).to match %r{all jobs started}
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
  end
end
