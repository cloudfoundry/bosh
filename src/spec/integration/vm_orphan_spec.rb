require 'spec_helper'

describe 'orphaning a vm', type: :integration do
  with_reset_sandbox_before_each

  let(:cloud_config) do
    cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
    cloud_config['networks'][0]['type'] = 'manual'
    cloud_config
  end

  let(:manifest) do
    manifest = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups(instances: 2)
    manifest['instance_groups'][0]['persistent_disk'] = 660
    manifest['update'] = manifest['update'].merge('vm_strategy' => 'create-swap-delete')
    manifest
  end

  before do
    deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
  end

  context 'when a create-swap-delete deployment succeeds on the first attempt' do
    it 'orphans the old vm' do
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)

      vms = table(bosh_runner.run('vms', json: true))
      expect(vms.length).to eq(2)

      orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
      expect(orphaned_vms.length).to eq(2)
    end
  end

  context 'when a create-swap-delete deployment fails' do
    it 'orphans the old vms upon a subsequent, successful deployment' do
      current_sandbox.cpi.commands.make_detach_disk_to_raise_not_implemented
      deploy_simple_manifest(manifest_hash: manifest, recreate: true, failure_expected: true)

      vms = table(bosh_runner.run('vms', json: true))
      expect(vms.length).to eq(4)

      orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
      expect(orphaned_vms.length).to eq(0)

      current_sandbox.cpi.commands.allow_detach_disk_to_succeed
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)

      vms = table(bosh_runner.run('vms', json: true))
      expect(vms.length).to eq(2)

      orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
      expect(orphaned_vms.length).to eq(4)
    end

    context 'when a create-swap-delete deployment fails multiple times' do
      it 'should not create more than a single inactive vm per instance' do
        current_sandbox.cpi.commands.make_detach_disk_to_raise_not_implemented
        deploy_simple_manifest(manifest_hash: manifest, recreate: true, failure_expected: true)

        vms = table(bosh_runner.run('vms', json: true))
        expect(vms.length).to eq(4)

        orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
        expect(orphaned_vms.length).to eq(0)

        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)

        vms = table(bosh_runner.run('vms', json: true))
        expect(vms.length).to eq(4)

        deploy_simple_manifest(manifest_hash: manifest, failure_expected: true)

        vms = table(bosh_runner.run('vms', json: true))
        expect(vms.length).to eq(4)

        orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
        expect(orphaned_vms.length).to eq(0)
      end
    end

    context 'when there is an unresponsive agent' do
      it 'successfully deploys' do
        director.instances.first.kill_agent
        deploy_simple_manifest(manifest_hash: manifest, recreate: true, fix: true)

        vms = table(bosh_runner.run('vms', json: true))
        expect(vms.length).to eq(2)

        # the second instance successfully orphans the existing vm
        orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
        expect(orphaned_vms.length).to eq(1)
      end

      context 'when the deloyment fails multiple times with some unrepsonsive vms' do
        it 'orphans only the responsive vms and does not release orphaned vm network plans' do
          current_sandbox.cpi.commands.make_detach_disk_to_raise_not_implemented
          deploy_simple_manifest(manifest_hash: manifest, recreate: true, failure_expected: true)

          vms = table(bosh_runner.run('vms', json: true))
          expect(vms.length).to eq(4)

          orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
          expect(orphaned_vms.length).to eq(0)

          director.instances.last.kill_agent

          current_sandbox.cpi.commands.allow_detach_disk_to_succeed
          deploy_simple_manifest(manifest_hash: manifest, recreate: true, fix: true)

          vms = table(bosh_runner.run('vms', json: true))
          expect(vms.length).to eq(2)

          orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
          expect(orphaned_vms.length).to eq(3)

          deploy_simple_manifest(manifest_hash: manifest, recreate: true)

          vms = table(bosh_runner.run('vms', json: true))
          expect(vms.length).to eq(2)

          orphaned_vms = table(bosh_runner.run('orphaned-vms', json: true))
          expect(orphaned_vms.length).to eq(5)
        end
      end
    end
  end
end
