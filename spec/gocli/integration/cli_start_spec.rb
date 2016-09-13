require_relative '../spec_helper'

describe 'start job', type: :integration do
  with_reset_sandbox_before_each

  it 'starts a job instance only' do
    deploy_from_scratch

    vm_before_with_index_1 = director.vms.find{ |vm| vm.index == '1'}
    instance_uuid = vm_before_with_index_1.instance_uuid

    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
    bosh_runner.run("stop", deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['stopped'])

    expect(bosh_runner.run('start foobar/0', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar:')
    vms_after_instance_started = director.vms
    vm_was_started = director.find_vm(vms_after_instance_started, 'foobar', '0')
    expect(vm_was_started.last_known_state).to eq ('running')
    expect((vms_after_instance_started -[vm_was_started]).map(&:last_known_state).uniq).to match_array(['stopped'])

    expect(bosh_runner.run("start foobar/#{instance_uuid}", deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar')
    vms_after_instance_started = director.vms
    vm_was_started = director.find_vm(vms_after_instance_started, 'foobar', instance_uuid)
    expect(vm_was_started.last_known_state).to eq ('running')
    expect((vms_after_instance_started -[vm_was_started]).map(&:last_known_state).uniq).to match_array(["running", "stopped"])
  end

  it 'starts vms for a given job / the whole deployment' do
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
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['stopped'])

    #only vms for one job should be started
    expect(bosh_runner.run('start foobar', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar:')
    vms_after_job_start = director.vms
    expect(director.find_vm(vms_after_job_start, 'foobar', '0').last_known_state).to eq('running')
    expect(director.find_vm(vms_after_job_start, 'foobar', '1').last_known_state).to eq('running')
    expect(director.find_vm(vms_after_job_start, 'another-job', '0').last_known_state).to eq('stopped')

    #all vms should be started
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['stopped'])
    output = bosh_runner.run('start', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(output).to include('Updating instance foobar')
    expect(output).to include('Updating instance another-job')
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
  end
end
