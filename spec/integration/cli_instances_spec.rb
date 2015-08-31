require 'spec_helper'

describe 'cli: instances', type: :integration do
  with_reset_sandbox_before_each

  it 'should return instances in a deployment' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    deploy_from_scratch(manifest_hash: manifest_hash)

    instances = bosh_runner.run('instances')
    expect(instances).to match /foobar\/0/
    expect(instances).to match /foobar\/1/
    expect(instances).to match /foobar\/2/
    expect(instances).to match /Instances total: 3/
  end

  it 'should return instances --vitals' do
    deploy_from_scratch
    vitals = director.instances_vitals[0]

    expect(vitals[:cpu_user]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_sys]).to match /\d+\.?\d*[%]/
    expect(vitals[:cpu_wait]).to match /\d+\.?\d*[%]/

    expect(vitals[:memory_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/
    expect(vitals[:swap_usage]).to match /\d+\.?\d*[%] \(\d+\.?\d*\w\)/

    expect(vitals[:system_disk_usage]).to match /\d+\.?\d*[%]/
    expect(vitals[:ephemeral_disk_usage]).to match /\d+\.?\d*[%]/

    # persistent disk was not deployed
    expect(vitals[:persistent_disk_usage]).to match /n\/a/
  end

  it 'should return instances --ps' do
    deploy_from_scratch
    instances_ps = director.instances_ps

    expect(instances_ps[0][:instance]).to match /foobar\/0/
    expect(instances_ps[1][:instance]).to match /process-1/
    expect(instances_ps[1][:state]).to match /running/
    expect(instances_ps[2][:instance]).to match /process-2/
    expect(instances_ps[2][:state]).to match /running/
  end
end
