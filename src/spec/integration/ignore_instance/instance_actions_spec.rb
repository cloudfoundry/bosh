require 'spec_helper'

describe 'instance actions', type: :integration do
  with_reset_sandbox_before_each

  it 'changes the state of all instances except the ignored ones' do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config

    manifest_hash['instance_groups'].clear
    manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 3)
    manifest_hash['instance_groups'] << SharedSupport::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 1)

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    def find_instance_by_index_and_name(instances, index, name)
      instances.find do |instance|
        instance.index == index && instance.instance_group_name == name
      end
    end

    instances_first_state = director.instances

    ignored_instance = find_instance_by_index_and_name(instances_first_state, '0', 'foobar1')
    foobar1_instance2 = find_instance_by_index_and_name(instances_first_state, '1', 'foobar1')
    foobar1_instance3 = find_instance_by_index_and_name(instances_first_state, '2', 'foobar1')
    foobar2_instance1 = find_instance_by_index_and_name(instances_first_state, '0', 'foobar2')

    bosh_runner.run("ignore #{ignored_instance.instance_group_name}/#{ignored_instance.id}", deployment_name: 'simple')

    # ===========================================
    start_output = bosh_runner.run('start', deployment_name: 'simple')
    expect(start_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(start_output).to_not include('Updating instance')

    # ===========================================
    stop_output = bosh_runner.run('stop', deployment_name: 'simple')
    expect(stop_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(stop_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(stop_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(stop_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(stop_output).to match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_stop = director.instances
    expect(find_instance_by_index_and_name(instances_after_stop, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_stop, '1', 'foobar1').last_known_state).to eq('stopped')
    expect(find_instance_by_index_and_name(instances_after_stop, '2', 'foobar1').last_known_state).to eq('stopped')
    expect(find_instance_by_index_and_name(instances_after_stop, '0', 'foobar2').last_known_state).to eq('stopped')

    # ===========================================
    restart_output = bosh_runner.run('restart', deployment_name: 'simple')
    expect(restart_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(restart_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(restart_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(restart_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(restart_output).to match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_restart = director.instances
    expect(find_instance_by_index_and_name(instances_after_restart, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_restart, '1', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_restart, '2', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_restart, '0', 'foobar2').last_known_state).to eq('running')

    # ===========================================
    recreate_output = bosh_runner.run('recreate', deployment_name: 'simple')
    expect(recreate_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(recreate_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(recreate_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(recreate_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(recreate_output).to match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_recreate = director.instances
    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_recreate, '1', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_recreate, '2', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar2').last_known_state).to eq('running')

    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar1').agent_id)
      .to eq(ignored_instance.agent_id)
    expect(find_instance_by_index_and_name(instances_after_recreate, '1', 'foobar1').agent_id)
      .to_not eq(foobar1_instance2.agent_id)
    expect(find_instance_by_index_and_name(instances_after_recreate, '2', 'foobar1').agent_id)
      .to_not eq(foobar1_instance3.agent_id)
    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar2').agent_id)
      .to_not eq(foobar2_instance1.agent_id)

    # ========================================================================================
    # Targeting an instance group
    # ========================================================================================

    stop_output = bosh_runner.run('stop foobar1', deployment_name: 'simple')
    expect(stop_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(stop_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(stop_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(stop_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(stop_output).to_not match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_stop = director.instances
    expect(find_instance_by_index_and_name(instances_after_stop, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_stop, '1', 'foobar1').last_known_state).to eq('stopped')
    expect(find_instance_by_index_and_name(instances_after_stop, '2', 'foobar1').last_known_state).to eq('stopped')
    expect(find_instance_by_index_and_name(instances_after_stop, '0', 'foobar2').last_known_state).to eq('running')

    # ===========================================
    start_output = bosh_runner.run('start foobar1', deployment_name: 'simple')
    expect(start_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(start_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(start_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(start_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(start_output).to_not match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_start = director.instances
    expect(find_instance_by_index_and_name(instances_after_start, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_start, '1', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_start, '2', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_start, '0', 'foobar2').last_known_state).to eq('running')

    # ===========================================
    restart_output = bosh_runner.run('restart foobar1', deployment_name: 'simple')
    expect(restart_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(restart_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(restart_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(restart_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(restart_output).to_not match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_restart = director.instances
    foobar1_instance2 = instances_after_restart[1]
    foobar1_instance3 = instances_after_restart[2]
    foobar2_instance1 = instances_after_restart[3]

    expect(find_instance_by_index_and_name(instances_after_restart, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_restart, '1', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_restart, '2', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_restart, '0', 'foobar2').last_known_state).to eq('running')

    # ===========================================
    recreate_output = bosh_runner.run('recreate foobar1', deployment_name: 'simple')
    expect(recreate_output).to include('Warning: You have ignored instances. They will not be changed.')
    expect(recreate_output).to_not match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(0\)})
    expect(recreate_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(1\)})
    expect(recreate_output).to match(%r{Updating instance foobar1: foobar1\/[a-z0-9\-]+ \(2\)})
    expect(recreate_output).to_not match(%r{Updating instance foobar2: foobar2\/[a-z0-9\-]+ \(0\)})

    instances_after_recreate = director.instances
    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_recreate, '1', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_recreate, '2', 'foobar1').last_known_state).to eq('running')
    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar2').last_known_state).to eq('running')

    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar1').agent_id)
      .to eq(ignored_instance.agent_id)
    expect(find_instance_by_index_and_name(instances_after_recreate, '1', 'foobar1').agent_id)
      .to_not eq(foobar1_instance2.agent_id)
    expect(find_instance_by_index_and_name(instances_after_recreate, '2', 'foobar1').agent_id)
      .to_not eq(foobar1_instance3.agent_id)
    expect(find_instance_by_index_and_name(instances_after_recreate, '0', 'foobar2').agent_id)
      .to eq(foobar2_instance1.agent_id)

    # ========================================================================================
    # Targeting a specific ignored instance
    # ========================================================================================
    stop_output, stop_exit_code = bosh_runner.run(
      "stop #{ignored_instance.instance_group_name}/#{ignored_instance.id}",
      failure_expected: true,
      return_exit_code: true,
      deployment_name: 'simple',
    )
    expect(stop_output).to include(
      "You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. " \
      'This operation is not allowed. You need to unignore it first.',
    )
    expect(stop_exit_code).to_not eq(0)

    start_output, start_exit_code = bosh_runner.run(
      "start #{ignored_instance.instance_group_name}/#{ignored_instance.id}",
      failure_expected: true,
      return_exit_code: true,
      deployment_name: 'simple',
    )
    expect(start_output).to include(
      "You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. " \
      'This operation is not allowed. You need to unignore it first.',
    )
    expect(start_exit_code).to_not eq(0)

    restart_output, restart_exit_code = bosh_runner.run(
      "restart #{ignored_instance.instance_group_name}/#{ignored_instance.id}",
      failure_expected: true,
      return_exit_code: true,
      deployment_name: 'simple',
    )
    expect(restart_output).to include(
      "You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. " \
      'This operation is not allowed. You need to unignore it first.',
    )
    expect(restart_exit_code).to_not eq(0)

    recreate_output, recreate_exit_code = bosh_runner.run(
      "recreate #{ignored_instance.instance_group_name}/#{ignored_instance.id}",
      failure_expected: true,
      return_exit_code: true,
      deployment_name: 'simple',
    )
    expect(recreate_output).to include(
      "You are trying to change the state of the ignored instance 'foobar1/#{ignored_instance.id}'. " \
      'This operation is not allowed. You need to unignore it first.',
    )
    expect(recreate_exit_code).to_not eq(0)
  end
end

