require 'spec_helper'

describe 'recreate job', type: :integration do
  with_reset_sandbox_before_each

  def vm_cids_for_job(job_name)
    director.vms.select { |vm| vm.job_name == job_name}.map(&:cid)
  end

  it 'recreates a job' do
    deploy_from_scratch
    original_cids = vm_cids_for_job('foobar')

    expect(bosh_runner.run('recreate foobar 0')).to match %r{foobar/0 has been recreated}
    expect((vm_cids_for_job('foobar') & original_cids).size).to eq(original_cids.size - 1)

    expect(bosh_runner.run('recreate foobar 1')).to match %r{foobar/1 has been recreated}
    expect((vm_cids_for_job('foobar') & original_cids).size).to eq(original_cids.size - 2)
  end

  it 'recreates a deployment' do
    deploy_from_scratch
    original_cids = vm_cids_for_job('foobar')

    bosh_runner.run('deploy --recreate')
    expect(vm_cids_for_job('foobar') & original_cids).to eq([])
  end
end
