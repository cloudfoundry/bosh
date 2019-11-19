require 'spec_helper'

describe 'keep unreachable vms', type: :integration do
  with_reset_sandbox_before_each(agent_wait_timeout: 1, keep_unreachable_vms: true)

  let(:cloud_config) do
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config['networks'][0]['type'] = 'manual'
    cloud_config
  end

  let(:manifest) do
    manifest = Bosh::Spec::Deployments.simple_manifest_with_instance_groups(instances: 1)
    manifest['instance_groups'][0]['jobs'] = []
    manifest
  end

  before do
    create_and_upload_test_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  context 'when creating a vm fails' do
    before do
      Thread.current[:sandbox].stop_nats
    end

    context 'without create-swap-delete' do
      it 'can successfully deploy after a failure' do
        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)
        task_logs = bosh_runner.run('task 3', failure_expected: true)
        expect(task_logs).to include('Timed out pinging')

        Thread.current[:sandbox].start_nats
        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)

        task_logs = bosh_runner.run('task 4', failure_expected: true)
        expect(task_logs).to include("Unknown CPI error 'IP Address 192.168.1.2 in network 'a' is already in use")
      end
    end

    context 'with create-swap-delete' do
      it 'can successfully orphan vms' do
        manifest['update'] = manifest['update'].merge('vm_strategy' => 'create-swap-delete')
        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)
        task_logs = bosh_runner.run('task 3', failure_expected: true)
        expect(task_logs).to include('Timed out pinging')

        Thread.current[:sandbox].start_nats
        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)

        task_logs = bosh_runner.run('task 4', failure_expected: true)
        expect(task_logs).to include("Unknown CPI error 'IP Address 192.168.1.2 in network 'a' is already in use")
      end
    end
  end
end
