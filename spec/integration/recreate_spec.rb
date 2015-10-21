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

  it 'recreates a VM with a different IP but maintains its DNS record', dns: true do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['name'] = 'first'
    manifest_hash['jobs'].first['name'] = 'first_job'
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['properties'] = { 'network_name' => 'a' }

    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config['networks'].first['type'] = 'dynamic'
    cloud_config['networks'].first['cloud_properties'] = {}
    cloud_config['networks'].first.delete('subnets')
    cloud_config['resource_pools'].first['size'] = 1

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')
    deploy_from_scratch(cloud_config_hash: cloud_config, manifest_hash: manifest_hash)
    output = bosh_runner.run('vms first --details --dns')
    expect(output).to include('127.0.0.101')
    expect(output).to include('0.first-job.a.first.bosh')

    current_sandbox.cpi.delete_vm(director.vms.first.cid)

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.102')
    set_deployment(manifest_hash: manifest_hash)
    output = bosh_runner.run('cck --auto')
    puts "output -- #{output}"

    output = bosh_runner.run('vms first --details --dns')
    expect(output).not_to include('127.0.0.101')
    expect(output).to include('127.0.0.102')
    expect(output).to include('0.first-job.a.first.bosh')
  end
end
