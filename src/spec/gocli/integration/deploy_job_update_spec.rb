require_relative '../spec_helper'

describe 'deploy job update', type: :integration do
  with_reset_sandbox_before_each
  let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config }
  let(:manifest_hash) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

  it 'updates a job with multiple instances in parallel and obeys max_in_flight' do
    manifest_hash['update']['canaries'] = 0
    manifest_hash['update']['max_in_flight'] = 2
    manifest_hash['properties'] = { 'test_property' => 2 }
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    task_id = bosh_runner.get_most_recent_task_id
    updating_job_events = events(task_id).select { |e| e['stage'] == 'Updating instance' }
    expect(updating_job_events[0]['state']).to eq('started')
    expect(updating_job_events[1]['state']).to eq('started')
    expect(updating_job_events[2]['state']).to eq('finished')
  end

  it 'updates a job taking into account max_in_flight and canaries as percents' do
    manifest_hash['update']['canaries'] = '40%'
    manifest_hash['update']['max_in_flight'] = '70%'
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    task_id = bosh_runner.get_most_recent_task_id
    updating_job_events = events(task_id).select { |e| e['stage'] == 'Updating instance' }
    expect(updating_job_events[0]['state']).to eq('started')
    expect(updating_job_events[0]['task']).to include('(canary)')
    expect(updating_job_events[1]['state']).to eq('finished')
    expect(updating_job_events[1]['task']).to include('(canary)')
    expect(updating_job_events[2]['state']).to eq('started')
    expect(updating_job_events[3]['state']).to eq('started')
    expect(updating_job_events[4]['state']).to eq('finished')
    expect(updating_job_events[5]['state']).to eq('finished')

    manifest_hash['instance_groups'][0]['instances'] = 1
    manifest_hash['update']['max_in_flight'] = '40%'
    deploy_simple_manifest(manifest_hash: manifest_hash)

    task_id = bosh_runner.get_most_recent_task_id
    deleting_job_events = events(task_id).select { |e| e['stage'] == 'Deleting unneeded instances' }
    expect(deleting_job_events[0]['state']).to eq('started')
    expect(deleting_job_events[1]['state']).to eq('finished')
    expect(deleting_job_events[2]['state']).to eq('started')
    expect(deleting_job_events[3]['state']).to eq('finished')
  end

  describe 'Displaying manifest diffs' do
    let(:runtime_config_hash) { Bosh::Spec::Deployments.runtime_config_with_addon }

    it 'accurately reports deployment configuration changes, cloud configuration changes and runtime config changes' do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      cloud_config_hash['vm_types'][0]['properties'] = {'prop1' => 'val1'}

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      upload_runtime_config(runtime_config_hash: runtime_config_hash)

      manifest_hash['update']['canary_watch_time'] = 0
      manifest_hash['instance_groups'][0]['instances'] = 2

      deploy_output = deploy(manifest_hash: manifest_hash, failure_expected: true, redact_diff: true)

      expect(deploy_output).to match(/vm_types:/)
      expect(deploy_output).to match(/update:/)
      expect(deploy_output).to match(/jobs:/)
      expect(deploy_output).to match(/addons:/)
      expect(deploy_output).to match(/dummy2/)

      # ensure it doesn't show the diff the second time
      deploy_output = deploy(manifest_hash: manifest_hash, failure_expected: true, redact_diff: true)

      expect(deploy_output).to_not match(/vm_types:/)
      expect(deploy_output).to_not match(/update:/)
      expect(deploy_output).to_not match(/jobs:/)
      expect(deploy_output).to_not match(/addons:/)
      expect(deploy_output).to_not match(/dummy2/)
    end

    context 'when using legacy deployment configuration' do
      let(:legacy_manifest_hash) { Bosh::Spec::Deployments.legacy_manifest }
      let(:modified_legacy_manifest_hash) do
        modified_legacy_manifest_hash = Bosh::Spec::Deployments.legacy_manifest
        modified_legacy_manifest_hash['resource_pools'][0]['size'] = 2
        modified_legacy_manifest_hash['update']['canary_watch_time'] = 0
        modified_legacy_manifest_hash['jobs'][0]['instances'] = 2
        modified_legacy_manifest_hash
      end

      context 'when previous deployment was in the legacy style' do
        before do
          create_and_upload_test_release
          upload_stemcell
          deploy_simple_manifest(manifest_hash: legacy_manifest_hash)
        end

        context 'when cloud config was uploaded' do
          before do
            upload_cloud_config(cloud_config_hash: cloud_config_hash)
          end

          context 'when new deployment was updated to not contain cloud properties' do
            it 'succeeds and correctly reports changes' do
              deploy_output = deploy(manifest_hash: manifest_hash, redact_diff: true)

              expect(deploy_output).to match(/- resource_pools:/)
              expect(deploy_output).to match(/\+ vm_types:/)
              expect(deploy_output).to_not match(/disk_pools:/)
            end
          end
        end
      end

      context 'when previous deployment was in the legacy style and there is no cloud config in the system' do
        before do
          create_and_upload_test_release
          upload_stemcell
          deploy_simple_manifest(manifest_hash: legacy_manifest_hash)
        end

        it 'correctly reports changes between the legacy deployments' do
          deploy_output = deploy(manifest_hash: modified_legacy_manifest_hash, failure_expected: true, redact_diff: true)
          expect(deploy_output).to match(/resource_pools:/)
          expect(deploy_output).to match(/update:/)
          expect(deploy_output).to match(/jobs:/)
        end
      end
    end
  end

  it 'stops deployment when a job update fails' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

    director.instance('foobar', '0').fail_job

    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'][0]['size'] = 2
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['update']['canary_watch_time'] = 0
    manifest_hash['instance_groups'][0]['instances'] = 2

    deploy_output, exit_code = deploy(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)

    task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id('error')
    task_events = events(task_id)

    failing_job_event = task_events[-2]
    expect(failing_job_event['stage']).to eq('Updating instance')
    expect(failing_job_event['state']).to eq('failed')
    expect(failing_job_event['task']).to match(/foobar\/[0-9a-f-]{36} \(0\) \(canary\)/)

    started_job_events = task_events.select do |e|
      e['stage'] == 'Updating instance' && e['state'] == 'started'
    end

    expect(started_job_events.size).to eq(1)
  end

  def start_and_finish_times_for_job_updates(task_id)
    jobs = {}
    events(task_id).select do |e|
      e['stage'] == 'Updating instance' && %w(started finished).include?(e['state'])
    end.each do |e|
      jobs[e['task']] ||= {}
      jobs[e['task']][e['state']] = e['time']
    end
    jobs
  end

  def events(task_id)
    result = bosh_runner.run("task #{task_id} --event", failure_expected: true)
    event_list = []
    result.each_line do |line|
      begin
        event = JSON.parse(line)
        event_list << event if event
      rescue JSON::ParserError
      end
    end
    event_list
  end
end
