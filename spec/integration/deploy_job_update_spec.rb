require 'spec_helper'

describe 'deploy job update', type: :integration do
  with_reset_sandbox_before_each

  it 'updates a job with multiple instances in parallel and obeys max_in_flight' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['update']['canaries'] = 0
    manifest_hash['update']['max_in_flight'] = 2
    manifest_hash['properties'] = { 'test_property' => 2 }
    deploy_from_scratch(manifest_hash: manifest_hash)

    updating_job_events = events('last').select { |e| e['stage'] == 'Updating job' }
    expect(updating_job_events[0]['state']).to eq('started')
    expect(updating_job_events[1]['state']).to eq('started')
    expect(updating_job_events[2]['state']).to eq('finished')
  end

  describe 'Displaying manifest diffs' do
    let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }
    let(:runtime_config_hash) { Bosh::Spec::Deployments.runtime_config_with_addon }
    let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }

    it 'accurately reports deployment configuration changes, cloud configuration changes and runtime config changes' do

      deploy_from_scratch

      bosh_runner.run("upload release #{spec_asset('dummy2-release.tgz')}")

      cloud_config_hash['resource_pools'][0]['size'] = 2

      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      upload_runtime_config(runtime_config_hash: runtime_config_hash)

      manifest_hash['update']['canary_watch_time'] = 0
      manifest_hash['jobs'][0]['instances'] = 2

      set_deployment(manifest_hash: manifest_hash)

      deploy_output = deploy(failure_expected: true, redact_diff: true)

      expect(deploy_output).to match(/resource_pools:/)
      expect(deploy_output).to match(/update:/)
      expect(deploy_output).to match(/jobs:/)
      expect(deploy_output).to match(/addons:/)
      expect(deploy_output).to match(/dummy2/)

      # ensure it doesn't show the diff the second time
      deploy_output = deploy(failure_expected: true, redact_diff: true)

      expect(deploy_output).to_not match(/resource_pools:/)
      expect(deploy_output).to_not match(/update:/)
      expect(deploy_output).to_not match(/jobs:/)
      expect(deploy_output).to_not match(/addons:/)
      expect(deploy_output).to_not match(/dummy2/)
    end

    context 'when using legacy deployment configuration' do
      let(:legacy_manifest_hash) { manifest_hash.merge(cloud_config_hash) }
      let(:modified_legacy_manifest_hash) do
        modified_legacy_manifest_hash = manifest_hash.merge(cloud_config_hash)
        modified_legacy_manifest_hash['resource_pools'][0]['size'] = 2
        modified_legacy_manifest_hash['update']['canary_watch_time'] = 0
        modified_legacy_manifest_hash['jobs'][0]['instances'] = 2
        modified_legacy_manifest_hash
      end

      context 'when previous deployment was in the legacy style' do
        before do
          target_and_login
          create_and_upload_test_release
          upload_stemcell
          deploy_simple_manifest(manifest_hash: legacy_manifest_hash)
        end

        context 'when cloud config was uploaded' do
          before do
            upload_cloud_config(cloud_config_hash: cloud_config_hash)
          end

          it 'fails to update deployment' do
            set_deployment(manifest_hash: modified_legacy_manifest_hash)

            deploy_output = deploy(failure_expected: true)
            expect(deploy_output).to match(/Deployment manifest should not contain cloud config properties/)
          end

          context 'when new deployment was updated to not contain cloud properties' do
            it 'succeeds and correctly reports changes' do
              set_deployment(manifest_hash: manifest_hash)

              deploy_output = deploy(redact_diff: true)
              expect(deploy_output).to_not match(/compilation:/)
              expect(deploy_output).to_not match(/resource_pools:/)
              expect(deploy_output).to_not match(/disk_pools:/)
            end
          end
        end
      end

      context 'when previous deployment was in the legacy style and there is no cloud config in the system' do
        before do
          target_and_login
          create_and_upload_test_release
          upload_stemcell
          deploy_simple_manifest(manifest_hash: legacy_manifest_hash)
        end

        it 'correctly reports changes between the legacy deployments' do
          set_deployment(manifest_hash: modified_legacy_manifest_hash)

          deploy_output = deploy(failure_expected: true, redact_diff: true)
          expect(deploy_output).to match(/resource_pools:/)
          expect(deploy_output).to match(/update:/)
          expect(deploy_output).to match(/jobs:/)
        end
      end
    end
  end

  it 'stops deployment when a job update fails' do
    deploy_from_scratch

    director.vm('foobar', '0').fail_job

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'][0]['size'] = 2
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['update']['canary_watch_time'] = 0
    manifest_hash['jobs'][0]['instances'] = 2
    set_deployment(manifest_hash: manifest_hash)

    deploy_output, exit_code = deploy(failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)

    task_id = Bosh::Spec::OutputParser.new(deploy_output).task_id('error')
    task_events = events(task_id)

    failing_job_event = task_events[-2]
    expect(failing_job_event['stage']).to eq('Updating job')
    expect(failing_job_event['state']).to eq('failed')
    expect(scrub_random_ids(failing_job_event['task'])).to eq('foobar/0 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) (canary)')

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
