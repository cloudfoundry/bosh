require 'spec_helper'

describe 'deployment integrations', type: :integration do
  with_reset_sandbox_before_each

  it 'updates job template accounting for deployment manifest properties' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['properties'] = { 'test_property' => 1 }
    deploy_simple(manifest_hash: manifest_hash)

    foobar_vm = director.vm('foobar/0')

    template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=1')

    manifest_hash['properties'] = { 'test_property' => 2 }
    deploy_simple_manifest(manifest_hash: manifest_hash)

    template = foobar_vm.read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('test_property=2')
  end

  it 'updates job template accounting for changed dynamic network configuration' do
    # Ruby agent does not determine dynamic ip for dummy infrastructure
    pending if current_sandbox.agent_type == "ruby"

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['networks'].first['type'] = 'dynamic'
    manifest_hash['networks'].first['cloud_properties'] = {}
    manifest_hash['networks'].first.delete('subnets')
    manifest_hash['resource_pools'].first['size'] = 1
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash['jobs'].first['properties'] = { 'network_name' => 'a' }

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.101')
    deploy_simple(manifest_hash: manifest_hash)

    # VM deployed for the first time knows about correct dynamic IP
    template = director.vm('foobar/0').read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.101')

    # Force VM recreation
    manifest_hash['resource_pools'].first['cloud_properties'] = {'changed' => true}

    current_sandbox.cpi.commands.make_create_vm_always_use_dynamic_ip('127.0.0.102')
    deploy_simple_manifest(manifest_hash: manifest_hash)

    # Recreated VM due to the resource pool change knows about correct dynamic IP
    template = director.vm('foobar/0').read_job_template('foobar', 'bin/foobar_ctl')
    expect(template).to include('a_ip=127.0.0.102')
  end

  it 'updates a job with multiple instances in parallel and obey max_in_flight' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['update']['canaries'] = 0
    manifest_hash['properties'] = { 'test_property' => 2 }
    manifest_hash['update']['max_in_flight'] = 2
    deploy_simple(manifest_hash: manifest_hash)

    times = start_and_finish_times_for_job_updates('last')
    expect(times['foobar/1']['started']).to be >= times['foobar/0']['started']
    expect(times['foobar/1']['started']).to be < times['foobar/0']['finished']
    expect(times['foobar/2']['started']).to be >= [times['foobar/0']['finished'], times['foobar/1']['finished']].min
  end

  it 'spawns a job and then successfully cancel it' do
    deploy_result = deploy_simple(no_track: true)
    task_id = Bosh::Spec::OutputParser.new(deploy_result).task_id('running')

    output, exit_code = bosh_runner.run("cancel task #{task_id}", return_exit_code: true)
    expect(output).to match(/Task #{task_id} is getting canceled/)
    expect(exit_code).to eq(0)

    error_event = events(task_id).last['error']
    expect(error_event['code']).to eq(10001)
    expect(error_event['message']).to eq("Task #{task_id} cancelled")
  end

  it 'does not finish a deployment if job update fails' do
    # Ruby agent does not implement fail_job functionality for integration testing
    pending if current_sandbox.agent_type == "ruby"

    deploy_simple

    director.vm('foobar/0').fail_job

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['update']['canary_watch_time'] = 0
    manifest_hash['jobs'][0]['instances'] = 2
    manifest_hash['resource_pools'][0]['size'] = 2

    set_deployment(manifest_hash: manifest_hash)
    deploy_output, exit_code = deploy(failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)

    task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id('error')
    task_events = events(task_id)

    failing_job_event = task_events[-2]
    expect(failing_job_event['stage']).to eq('Updating job')
    expect(failing_job_event['state']).to eq('failed')
    expect(failing_job_event['task']).to eq('foobar/0 (canary)')

    started_job_events = task_events.select do |e|
      e['stage'] == 'Updating job' && e['state'] == "started"
    end

    expect(started_job_events.size).to eq(1)
  end

  def start_and_finish_times_for_job_updates(task_id)
    jobs = {}
    events(task_id).select do |e|
      e['stage'] == 'Updating job' && %w(started finished).include?(e['state'])
    end.each do |e|
      jobs[e['task']] ||= {}
      jobs[e['task']][e['state']] = e['time']
    end
    jobs
  end

  def events(task_id)
    result = bosh_runner.run("task #{task_id} --raw")
    event_list = []
    result.each_line do |line|
      begin
        event = Yajl::Parser.new.parse(line)
        event_list << event if event
      rescue Yajl::ParseError
      end
    end
    event_list
  end
end
