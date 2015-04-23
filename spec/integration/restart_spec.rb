require 'spec_helper'

describe 'restart job', type: :integration do
  with_reset_sandbox_before_each

  it 'restarts a job' do
    deploy_from_scratch
    expect(bosh_runner.run('restart foobar 0')).to match %r{foobar/0 has been restarted}
  end
end
