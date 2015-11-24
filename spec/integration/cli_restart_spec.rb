require 'spec_helper'

describe 'restart job', type: :integration do
  with_reset_sandbox_before_each

  it 'restarts a job instance / job / all jobs' do
    deploy_from_scratch
    expect(bosh_runner.run('restart foobar 0')).to match %r{foobar/0 restarted}
    expect(bosh_runner.run('restart foobar')).to match %r{foobar/\* restarted}
    expect(bosh_runner.run('restart')).to match %r{all jobs restarted}
  end
end
