require 'spec_helper'

describe 'deploy job update', type: :integration do
  with_reset_sandbox_before_each

  it 'updates a job with multiple instances in parallel and obeys max_in_flight' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['update']['canaries'] = 0
    manifest_hash['update']['max_in_flight'] = 2
    manifest_hash['properties'] = { 'test_property' => 2 }
    deploy_simple(manifest_hash: manifest_hash)

    times = start_and_finish_times_for_job_updates('last')
    expect(times['foobar/1']['started']).to be >= times['foobar/0']['started']
    expect(times['foobar/1']['started']).to be < times['foobar/0']['finished']
    expect(times['foobar/2']['started']).to be >= [times['foobar/0']['finished'], times['foobar/1']['finished']].min
  end

  it 'stops deployment when a job update fails' do
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
