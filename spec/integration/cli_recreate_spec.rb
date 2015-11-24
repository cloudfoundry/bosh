require 'spec_helper'

describe 'recreate job', type: :integration do
  with_reset_sandbox_before_each

  it 'recreates a job instance / job / all jobs' do
    deploy_from_scratch
    expect(bosh_runner.run('recreate foobar 0')).to match %r{foobar/0 recreated}
    expect(bosh_runner.run('recreate foobar')).to match %r{foobar/\* recreated}
    initial_vms = director.vms
    expect(bosh_runner.run('recreate')).to match %r{all jobs recreated}
    expect(director.vms).not_to match_array(initial_vms.map(&:cid))
  end
end
