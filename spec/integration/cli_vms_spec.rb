require 'spec_helper'

describe 'cli: vms', type: :integration do
  with_reset_sandbox_before_each

  it 'should return vms in a deployment' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    deploy_from_scratch(manifest_hash: manifest_hash)

    vms = bosh_runner.run('vms')
    expect(vms).to match /foobar\/0/
    expect(vms).to match /foobar\/1/
    expect(vms).to match /foobar\/2/
    expect(vms).to match /VMs total: 3/
  end

  it 'should return vm --vitals' do
    deploy_from_scratch
    vitals = director.vms_vitals[0]

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
end
