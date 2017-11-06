require_relative '../../spec_helper'

describe 'health_monitor: 1', type: :integration, hm: true do
  with_reset_sandbox_before_each
  with_reset_hm_before_each

  # ~1m20s
  it 'resurrects stateless nodes if agent is not responding' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    original_instance = director.instance('foobar', '0', deployment_name: 'simple')
    original_instance.kill_agent
    resurrected_instance = director.wait_for_vm('foobar', '0', 300, deployment_name: 'simple')
    expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
  end

  # ~5m
  it 'resurrects stateless nodes if vm is missing for instance' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    current_sandbox.cpi.commands.make_create_vm_always_fail

    original_instance = director.instance('foobar', '0', deployment_name: 'simple')
    original_instance.kill_agent

    resurrected_instance = director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple')
    expect(resurrected_instance).to be_nil

    current_sandbox.cpi.commands.allow_create_vm_to_succeed
    resurrected_instance = director.wait_for_vm('foobar', '0', 300, deployment_name: 'simple')
    expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
  end


  it 'runs the pre-start scripts when the VM is resurrected' do
    manifest_hash = Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge({
                        'instance_groups' => [Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                                       name: 'ig_with_jobs_having_prestart_scripts',
                                       jobs: [
                                           {'name' => 'job_1_with_pre_start_script'},
                                           {'name' => 'job_2_with_pre_start_script'}
                                       ],
                                       instances: 1)]
                    })

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    original_instance = director.instance('ig_with_jobs_having_prestart_scripts', '0', deployment_name: 'simple')
    original_instance.kill_agent
    resurrected_instance = director.wait_for_vm('ig_with_jobs_having_prestart_scripts', '0', 300, deployment_name: 'simple')
    expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)

    waiter = Bosh::Spec::Waiter.new(logger)
    waiter.wait(50) do
      agent_id = resurrected_instance.agent_id

      agent_log = File.read("#{current_sandbox.agent_tmp_path}/agent.#{agent_id}.log")
      expect(agent_log).to include("/jobs/job_1_with_pre_start_script/bin/pre-start' script has successfully executed")
      expect(agent_log).to include("/jobs/job_2_with_pre_start_script/bin/pre-start' script has successfully executed")

      job_1_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stdout.log")
      expect(job_1_stdout).to match("message on stdout of job 1 pre-start script\ntemplate interpolation works in this script: this is pre_start_message_1")

      job_1_stderr = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_1_with_pre_start_script/pre-start.stderr.log")
      expect(job_1_stderr).to match('message on stderr of job 1 pre-start script')

      job_2_stdout = File.read("#{current_sandbox.agent_tmp_path}/agent-base-dir-#{agent_id}/data/sys/log/job_2_with_pre_start_script/pre-start.stdout.log")
      expect(job_2_stdout).to match('message on stdout of job 2 pre-start script')
    end
  end

  # ~8m
  it 'does not resurrect stateless nodes when paused' do
    pending('cli2: #130336999: cli should allow setting resurrection per vm')
    deploy_from_scratch

    bosh_runner.run('vm resurrection off', deployment_name: 'simple')
    bosh_runner.run('vm resurrection foobar/1 on', deployment_name: 'simple')

    director.instance('foobar', '0', deployment_name: 'simple').kill_agent
    director.instance('foobar', '1', deployment_name: 'simple').kill_agent

    expect(director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple')).to be_nil
    expect(director.wait_for_vm('foobar', '1', 10, deployment_name: 'simple')).to be_nil
  end

  # ~4m
  it 'only resurrects stateless nodes that are configured to be resurrected' do
    skip 'The interaction of a resurrected node and a non-resurrected node are important but broken. See #69728124'

    deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    deployment_hash['jobs'][0]['instances'] = 2
    deploy_from_scratch(manifest_hash: deployment_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    bosh_runner.run('vm resurrection foobar/1 off', deployment_name: 'simple')

    original_0_instance = director.instance('foobar', '0', deployment_name: 'simple')
    original_1_instance = director.instance('foobar', '1', deployment_name: 'simple')

    # Kill VMs as close as possible
    original_0_instance.kill_agent
    original_1_instance.kill_agent

    new_0_instance = director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple')
    expect(new_0_instance.vm_cid).to_not eq(original_0_instance.vm_cid)

    # Since at this point 0th VM is back up, assume that
    # if 1st VM would be resurrected it would've already happened
    # (i.e do not wait for long time)
    new_1_instance = director.wait_for_vm('foobar', '1', 10, deployment_name: 'simple')
    expect(new_1_instance).to be_nil
  end

  # ~3m
  it 'resurrects vms that were down before resurrector started' do
    # Turn resurrector off
    current_sandbox.reconfigure_health_monitor('health_monitor_without_resurrector.yml.erb')

    deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    deployment_hash['instance_groups'][0]['instances'] = 2
    deploy_from_scratch(manifest_hash: deployment_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    director.instance('foobar', '0', deployment_name: 'simple').kill_agent
    director.instance('foobar', '1', deployment_name: 'simple').kill_agent

    _, exit_code = bosh_runner.run('cck --report', deployment_name: 'simple', failure_expected: true, return_exit_code: true)
    expect(exit_code).to eq(1)

    # Turn resurrector back on
    current_sandbox.reconfigure_health_monitor('health_monitor.yml.erb')

    expect(director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple')).to_not be_nil
    expect(director.wait_for_vm('foobar', '1', 150, deployment_name: 'simple')).to_not be_nil
  end

  context 'when the vm is launching and has incomplete heartbeats' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    it 'only outputs complete heartbeats' do
      team_client_env = {'BOSH_CLIENT' => 'team-client', 'BOSH_CLIENT_SECRET' => 'team-secret'}
      director_client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}

      current_sandbox.reconfigure_health_monitor('health_monitor_with_json_logging.yml.erb')

      deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      deployment_hash['instance_groups'][0]['instances'] = 1

      prepare_for_deploy(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config, no_login: true, env: director_client_env, include_credentials: false)
      deploy_simple_manifest(manifest_hash: deployment_hash, no_login: true, env: team_client_env, include_credentials: false)

      start_time = Time.now
      while Time.now < start_time + 60
        heartbeat_lines = []
        health_monitor.read_log.split("\n").inject(heartbeat_lines) do |lines, line|
          match_data = /I, \[.* \#\d*\]  INFO : (\{\"kind\"\:\"heartbeat\".*)/.match(line)
          lines << match_data[1] if match_data
          lines
        end

        break if !heartbeat_lines.empty?
      end

      heartbeat_hashes = heartbeat_lines.map {|json_line| JSON.parse(json_line) }

      instances = director.instances(no_login: true, env: team_client_env, include_credentials: false)
      instance = instances.first
      expected_hash = {
          'kind' => 'heartbeat',
          'id' => anything,
          'timestamp' => anything,
          'deployment' => deployment_hash['name'],
          'agent_id' => instance.agent_id,
          'job' => instance.job_name,
          'index' => instance.index,
          'instance_id' => instance.id,
          'job_state' => 'running',
          'vitals' => anything,
          'teams' => ['ateam'],
          'metrics' => anything,
      }

      heartbeat_hashes_excluding_compilation = heartbeat_hashes.select do |hash|
        hash['job'] !=~ /^compilation\-/
      end

      expect(heartbeat_hashes_excluding_compilation.length).to be > 0
      heartbeat_hashes_excluding_compilation.each do |heartbeat_hash|
        expect(heartbeat_hash).to match(expected_hash)
      end
    end
  end

  # ~50s
  it 'notifies health monitor about job failures' do
    deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    deployment_hash['instance_groups'][0]['instances'] = 1
    deploy_from_scratch(manifest_hash: deployment_hash,  cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    director.instance('foobar', '0').fail_job
    waiter.wait(20) { expect(health_monitor.read_log).to match(/\[ALERT\] Alert @ .* fake-monit-description/) }
  end

  it 're-renders templates with new dynamic network IPs' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash['instance_groups'].first['networks'] << {'name' => 'b', 'default' => ['dns', 'gateway']}
    manifest_hash['instance_groups'].first['jobs'].first['properties'] = { 'networks' => ['a', 'b'] }

    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config['networks'] << {
      'name' => 'b',
      'type' => 'dynamic',
      'cloud_properties' => {}
    }

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    original_instance = director.instance('foobar', '0', deployment_name: 'simple')
    template = original_instance.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=192.168.1.2')
    expect(template).to include('b_ip=127.0.0.101')

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.102')
    resurrected_instance = director.kill_vm_and_wait_for_resurrection(original_instance)

    template = resurrected_instance.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=192.168.1.2')
    expect(template).to include('b_ip=127.0.0.102')
  end
end
