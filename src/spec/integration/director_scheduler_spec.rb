require 'spec_helper'
require 'minitar'
require 'zlib'

describe 'director_scheduler', type: :integration do
  with_reset_sandbox_before_each

  let(:deployment_hash) do
    deployment_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    deployment_hash['instance_groups'][0]['persistent_disk'] = 20_480
    deployment_hash
  end

  let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

  before do
    runner.run('create-release --force')
    runner.run('upload-release')
    runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")

    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")

    deployment_manifest = yaml_file('deployment_manifest', deployment_hash)
    runner.run("deploy -d simple #{deployment_manifest.path}")
  end

  describe 'scheduled disk snapshots' do
    before { current_sandbox.scheduler_process.start }
    after { current_sandbox.scheduler_process.stop }

    it 'snapshots a disk' do
      waiter.wait(300) { expect(snapshots).to_not be_empty }

      keys = %w[deployment job index director_name director_uuid agent_id instance_id]
      snapshots.each do |snapshot|
        json = JSON.parse(File.read(snapshot))
        expect(json.keys - keys).to be_empty
      end
    end

    def snapshots
      Dir[File.join(current_sandbox.agent_tmp_path, 'snapshots', '*')]
    end
  end

  describe 'orphaned VMs cleanup' do
    before { current_sandbox.scheduler_process.start }
    after { current_sandbox.scheduler_process.stop }

    let(:deployment_hash) do
      deployment_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
      deployment_hash['instance_groups'][0]['update'] = {
        'vm_strategy' => 'create-swap-delete',
      }
      deployment_hash
    end

    it 'cleans up VMs' do
      runner.run('recreate -d simple')

      waiter.wait(300) do
        output = runner.run('events', json: true)
        events = scrub_event_time(scrub_random_cids(scrub_random_ids(table(output)))).select do |event|
          event['user'] == 'scheduler' && event['object_type'] != 'lock'
        end

        expect(events.length).to eq(2 * deployment_hash['instance_groups'][0]['instances'])
        event = {
          'id' => /[0-9]{1,}/,
          'time' => 'xxx xxx xx xx:xx:xx UTC xxxx',
          'user' => 'scheduler',
          'action' => 'delete',
          'object_type' => 'vm',
          'task_id' => /[0-9]{1,}/,
          'object_name' => /[0-9]{1,}/,
          'deployment' => 'simple',
          'instance' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          'context' => '',
          'error' => '',
        }
        parented_event = event.dup
        parented_event['id'] = /[0-9]{1,} <- [0-9]{1,}/

        expect(events).to contain_exactly(parented_event, event, parented_event, event, parented_event, event)
      end
    end
  end
end
