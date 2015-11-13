require 'spec_helper'

describe 'stop job', type: :integration do
  with_reset_sandbox_before_each

  it 'stops a job' do
    deploy_from_scratch
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
    expect(bosh_runner.run('stop foobar')).to include("foobar/* stopped, VM(s) still running")
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['stopped'])
  end

  it 'stops a deployment' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs']<< {
        'name' => 'another-job',
        'template' => 'foobar',
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
    }
    manifest_hash['jobs'].first['instances']= 2
    deploy_from_scratch(manifest_hash: manifest_hash)
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
    expect(bosh_runner.run('stop')).to include("all jobs stopped, VM(s) still running")
    vms = director.vms
    expect(vms.map(&:job_name_index)).to match_array(['another-job/0', 'foobar/0', 'foobar/1'])
    expect(vms.map(&:last_known_state).uniq).to match_array(['stopped'])
  end

  it 'stops a job instance and deletes vm' do
    deploy_from_scratch
    expect(director.vms.count).to eq(3)
    expect(bosh_runner.run('stop foobar 0 --hard')).to include("foobar/0 detached, VM(s) deleted")
    vms = director.vms
    expect(vms.count).to eq(2)
    expect(vms.map(&:job_name_index)).to match_array(['foobar/1', 'foobar/2'])
  end
end
