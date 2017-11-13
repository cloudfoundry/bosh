require_relative '../spec_helper'

describe 'start job', type: :integration do
  with_reset_sandbox_before_each

  it 'starts a job instance only' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups)

    instance_before_with_index_1 = director.instances.find{ |instance| instance.index == '1'}
    instance_uuid = instance_before_with_index_1.id

    expect(director.instances.map(&:last_known_state).uniq).to match_array(['running'])
    bosh_runner.run("stop", deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])

    expect(bosh_runner.run('start foobar/0', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar:')
    instances_after_instance_started = director.instances
    instance_was_started = director.find_instance(instances_after_instance_started, 'foobar', '0')
    expect(instance_was_started.last_known_state).to eq ('running')
    expect((instances_after_instance_started -[instance_was_started]).map(&:last_known_state).uniq).to match_array(['stopped'])

    expect(bosh_runner.run("start foobar/#{instance_uuid}", deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar')
    instances_after_instance_started = director.instances
    instance_was_started = director.find_instance(instances_after_instance_started, 'foobar', instance_uuid)
    expect(instance_was_started.last_known_state).to eq ('running')
    expect((instances_after_instance_started -[instance_was_started]).map(&:last_known_state).uniq).to match_array(["running", "stopped"])
  end

  it 'starts vms for a given job / the whole deployment' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups']<< {
      'name' => 'another-job',
      'jobs' => [{'name'=> 'foobar'}],
      'vm_type' => 'a',
      'instances' => 1,
      'networks' => [{'name' => 'a'}],
      'stemcell' => 'default',
    }

    manifest_hash['instance_groups'].first['instances'] = 2
    deploy_from_scratch(manifest_hash: manifest_hash)
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])

    #only vms for one job should be started
    expect(bosh_runner.run('start foobar', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar:')
    instances_after_job_start = director.instances
    expect(director.find_instance(instances_after_job_start, 'foobar', '0').last_known_state).to eq('running')
    expect(director.find_instance(instances_after_job_start, 'foobar', '1').last_known_state).to eq('running')
    expect(director.find_instance(instances_after_job_start, 'another-job', '0').last_known_state).to eq('stopped')

    #all vms should be started
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])
    output = bosh_runner.run('start', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(output).to include('Updating instance foobar')
    expect(output).to include('Updating instance another-job')
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['running'])
  end

  it 'respects --canaries' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups']<< {
      'name' => 'another-job',
      'jobs' => [{'name' => 'foobar'}],
      'vm_type' => 'a',
      'instances' => 1,
      'networks' => [{'name' => 'a'}],
      'stemcell' => 'default',
    }

    manifest_hash['update']['canaries'] = 0
    manifest_hash['instance_groups'].first['instances']= 5
    deploy_from_scratch(manifest_hash: manifest_hash)
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])

    #only vms for one job should be started
    expect(bosh_runner.run('start foobar', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar:')
    instances_after_job_start = director.instances
    expect(director.find_instance(instances_after_job_start, 'foobar', '0').last_known_state).to eq('running')
    expect(director.find_instance(instances_after_job_start, 'foobar', '1').last_known_state).to eq('running')
    expect(director.find_instance(instances_after_job_start, 'another-job', '0').last_known_state).to eq('stopped')

    #all vms should be started
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])
    output = bosh_runner.run('start --canaries 2', json: true, deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    lines = parse_blocks(output)

    foobar_canary_regex = /Updating instance foobar: foobar\/[0-9a-f]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12} \(\d\) \(canary\)/

    foobar_canary_lines = lines.select { |line| foobar_canary_regex.match(line) }
    expect(foobar_canary_lines.size).to eq(2)

    expect(director.instances.map(&:last_known_state).uniq).to match_array(['running'])
  end

  it 'respects --max-in-flight' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups']<< {
      'name' => 'another-job',
      'jobs' => [{'name' => 'foobar'}],
      'vm_type' => 'a',
      'instances' => 1,
      'networks' => [{'name' => 'a'}],
      'stemcell' => 'default',
    }

    manifest_hash['update']['max_in_flight'] = 20
    manifest_hash['update']['canaries'] = 0
    manifest_hash['instance_groups'].first['instances']= 10
    deploy_from_scratch(manifest_hash: manifest_hash)
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])

    #only vms for one job should be started
    expect(bosh_runner.run('start foobar', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)).to include('Updating instance foobar:')
    instances_after_job_start = director.instances
    expect(director.find_instance(instances_after_job_start, 'foobar', '0').last_known_state).to eq('running')
    expect(director.find_instance(instances_after_job_start, 'foobar', '1').last_known_state).to eq('running')
    expect(director.find_instance(instances_after_job_start, 'another-job', '0').last_known_state).to eq('stopped')

    #all vms should be started
    bosh_runner.run('stop', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])
    output = bosh_runner.run('start --max-in-flight 1', deployment_name: Bosh::Spec::Deployments::DEFAULT_DEPLOYMENT_NAME, json: true)
    lines = parse_blocks(output)

    foobar_update_regex = /Updating instance foobar: foobar\/[0-9a-f]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12} \(\d\)/

    foobar_update_lines = lines.select { |l| foobar_update_regex.match(l) }
    expect(foobar_update_lines.size).to eq(10)

    expect(output).to include('Updating instance another-job')
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['running'])
  end
end
