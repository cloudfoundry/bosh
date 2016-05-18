require 'spec_helper'

describe 'ignore/unignore instance', type: :integration do
  with_reset_sandbox_before_each

  it 'changes the ignore value of vms correctly' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    director.vms.each do |vm|
      expect(vm.ignore).to eq('false')
    end

    initial_vms = director.vms
    vm1 = initial_vms[0]
    vm2 = initial_vms[1]
    vm3 = initial_vms[2]

    bosh_runner.run("ignore instance #{vm1.job_name}/#{vm1.instance_uuid}")
    bosh_runner.run("ignore instance #{vm2.job_name}/#{vm2.instance_uuid}")
    expect(director.vm(vm1.job_name, vm1.instance_uuid).ignore).to eq('true')
    expect(director.vm(vm2.job_name, vm2.instance_uuid).ignore).to eq('true')
    expect(director.vm(vm3.job_name, vm3.instance_uuid).ignore).to eq('false')

    bosh_runner.run("unignore instance #{vm2.job_name}/#{vm2.instance_uuid}")
    expect(director.vm(vm1.job_name, vm1.instance_uuid).ignore).to eq('true')
    expect(director.vm(vm2.job_name, vm2.instance_uuid).ignore).to eq('false')
    expect(director.vm(vm3.job_name, vm3.instance_uuid).ignore).to eq('false')
  end
end
