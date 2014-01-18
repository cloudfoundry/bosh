require 'spec_helper'

describe 'deployment integrations' do
  include IntegrationExampleGroup

  describe 'static drain' do
    it 'runs the drain script on a job if drain script is present' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['resource_pools'][0]['size'] = 1
      deploy_simple(manifest_hash: manifest_hash)

      manifest_hash['properties'] ||= {}
      manifest_hash['properties']['test_property'] = 0
      deploy_simple_manifest(manifest_hash: manifest_hash)

      agent_files = Dir["#{current_sandbox.agent_tmp_path}/agent-base-dir-*/*"]
      drain_output = agent_files.detect { |f| File.basename(f) == 'drain-test.log' }
      expect(File.read(drain_output)).to eq("job_unchanged hash_changed\n1\n")
    end
  end

  describe 'dynamic drain' do
    it 'retries after the appropriate amount of time' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['resource_pools'][0]['size'] = 1
      manifest_hash['properties'] ||= {}
      manifest_hash['properties']['drain_type'] = 'dynamic'
      deploy_simple(manifest_hash: manifest_hash)

      manifest_hash['properties']['test_property'] = 0
      deploy_simple_manifest(manifest_hash: manifest_hash)

      agent_files = Dir["#{current_sandbox.agent_tmp_path}/agent-base-dir-*/*"]
      drain_output = agent_files.detect { |f| File.basename(f) == 'drain-test.log' }
      drain_times = File.read(drain_output).split.map { |time| time.to_i }
      expect(drain_times.size).to eq(3)
      expect(drain_times[1] - drain_times[0]).to be >= 3
      expect(drain_times[2] - drain_times[1]).to be >= 2
    end
  end

  context 'updating jobs in parallel' do
    it 'should update a job with multiple instances in parallel and obey max_in_flight' do
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
  end

  context 'canceling a deploy job' do
    it 'should spawn a job and then successfully cancel it' do
      deploy_result = deploy_simple(no_track: true)
      task_id = get_task_id(deploy_result, 'running')

      # If you don't have this sleep, events() will hang
      # And, yes, you need it before "cancel task"
      sleep(5) # Wait for deployment to start
      cancel_output = run_bosh("cancel task #{task_id}")
      expect($?).to be_success
      expect(cancel_output).to match /Task #{task_id} is getting canceled/

      error_event = events(task_id).last['error']
      expect(error_event['code']).to eq(10001)
      expect(error_event['message']).to eq("Task #{task_id} cancelled")
    end
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
    result = run_bosh("task #{task_id} --raw")
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

  def get_task_id(output, state = 'done')
    match = output.match(/Task (\d+) #{state}/)
    expect(match).to_not be(nil)
    match[1]
  end
end
