require 'spec_helper'

describe 'recreate job', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates a job' do
    deploy_from_scratch
    expect(bosh_runner.run('recreate foobar 0')).to match %r{foobar/0 has been recreated}
    expect(bosh_runner.run('recreate foobar 1')).to match %r{foobar/1 has been recreated}
  end
end
