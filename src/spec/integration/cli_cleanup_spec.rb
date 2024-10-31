require 'spec_helper'
require 'fileutils'

describe 'cli: cleanup', type: :integration do
  with_reset_sandbox_before_each(local_dns: {'enabled' => true, 'include_index' => false})

  def ensure_orphaned_vms_exist(manifest_hash)
    manifest_hash['update'] = manifest_hash['update'].merge('vm_strategy' => 'create-swap-delete')
    deploy_simple_manifest(manifest_hash: manifest_hash, recreate: true)
    expect(table(bosh_runner.run('orphaned-vms', json: true))).to_not be_empty
  end

  shared_examples_for 'removing an exported release' do
    before do
      bosh_runner.run("upload-release #{asset_path('test_release.tgz')}")
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
      bosh_runner.run("upload-stemcell #{asset_path('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")

      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      upload_cloud_config(cloud_config)
      manifest_hash = SharedSupport::DeploymentManifestHelper.minimal_manifest
      deploy_simple_manifest(manifest_hash: manifest_hash)

      bosh_runner.run('export-release test_release/1 toronto-os/1', deployment_name: 'minimal')
      bosh_runner.run('export-release test_release/1 centos-7/3001', deployment_name: 'minimal')
    end

    it 'should clean up compiled exported releases of compiled releases' do
      output = bosh_runner.run(clean_command)

      expect(output).to include('Deleting exported releases')
      expect(output.scan(/Deleting exported releases/).count).to eq(2)
      expect(output).to include('Succeeded')
    end
  end

  context 'clean-up' do
    let(:clean_command) { 'clean-up' }

    it 'should remove orphaned vms, releases, stemcells and dns blobs, leaving recent versions. Also leaves orphaned disks.' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['name'] = 'deployment-a'
      manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(persistent_disk_type: 'disk_a', instances: 1, name: 'first-job'),
      ]
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      disk_type = SharedSupport::DeploymentManifestHelper.disk_type
      disk_type['cloud_properties'] = { 'my' => 'property' }
      cloud_config['disk_types'] = [disk_type]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      upload_new_release_version('file-1.txt')
      upload_new_release_version('file-2.txt')

      disk_cid = director.instances(deployment_name: 'deployment-a')[0].disk_cids[0]

      ensure_orphaned_vms_exist(manifest_hash)

      bosh_runner.run('delete-deployment', deployment_name: 'deployment-a')

      bosh_runner.run(clean_command)

      expect(table(bosh_runner.run('disks --orphaned', json: true))[0]['disk_cid']).to eq(disk_cid)
      expect(table(bosh_runner.run('orphaned-vms', json: true))).to be_empty

      releases_output = table(bosh_runner.run('releases', json: true))
      release_versions = releases_output.map { |r| r['version'] }
      expect(release_versions).to_not include('0+dev.1')
      expect(release_versions).to include('0+dev.2')
      expect(release_versions).to include('0+dev.3')

      stemcell_output = table(bosh_runner.run('stemcells', json: true))
      stemcells = stemcell_output.map { |r| r['name'] }
      expect(stemcells).to include('ubuntu-stemcell')
      expect(stemcells.length).to eq(1)
    end

    context 'when there are compiled releases in the blobstore' do
      include_examples 'removing an exported release'
    end
  end

  context 'clean-up --all' do
    let(:clean_command) { 'clean-up --all' }

    it 'should remove orphaned disks, releases, stemcells, and all unused dns blobs' do
      manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest_hash['name'] = 'deployment-a'
      manifest_hash['instance_groups'] = [
        SharedSupport::DeploymentManifestHelper.simple_instance_group(persistent_disk_type: 'disk_a', instances: 1, name: 'first-job'),
      ]
      cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
      disk_type = SharedSupport::DeploymentManifestHelper.disk_type
      disk_type['cloud_properties'] = { 'my' => 'property' }
      cloud_config['disk_types'] = [disk_type]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      bosh_runner.run('delete-deployment', deployment_name: 'deployment-a')
      bosh_runner.run(clean_command)

      clean_task_id = bosh_runner.get_most_recent_task_id
      cleanup_debug_logs = bosh_runner.run("task #{clean_task_id} --debug")
      expect(cleanup_debug_logs).to match(/Deleting dns blobs/)

      output = table(bosh_runner.run('releases', failure_expected: true, json: true))
      expect(output).to eq([])
      output = table(bosh_runner.run('stemcells', failure_expected: true, json: true))
      expect(output).to eq([])
      output = table(bosh_runner.run('disks --orphaned', failure_expected: true, json: true))
      expect(output).to eq([])
    end

    context 'when there is a runtime config uploaded' do
      it 'does not remove the releases specified in the runtime config' do
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
        cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, runtime_config_hash: {
          'releases' => [{ 'name' => 'bosh-release', 'version' => '0+dev.1' }],
        })

        bosh_runner.run('delete-deployment', deployment_name: 'simple')

        bosh_runner.run(clean_command)
        releases_output = table(bosh_runner.run('releases', json: true))
        release_versions = releases_output.map { |r| r['version'] }
        expect(release_versions).to include('0+dev.1')
      end
    end

    context 'when there are compiled releases in the blobstore' do
      include_examples 'removing an exported release'
    end

    context 'when errands that ran have changing jobs' do
      let(:manifest) do
        manifest = SharedSupport::DeploymentManifestHelper.manifest_with_errand
        manifest['releases'].first['version'] = 'latest'
        manifest
      end
      let(:deployment_name) { manifest['name'] }

      before do
        deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
        bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

        Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
          open('jobs/errand1/templates/run', 'a') { |f| f.puts 'echo "bye"' }
          bosh_runner.run_in_current_dir('create-release --force --timestamp-version')
          bosh_runner.run_in_current_dir('upload-release')
        end

        deploy_simple_manifest(manifest_hash: manifest)
      end

      it 'should clean up compiled exported releases of compiled releases' do
        output = bosh_runner.run(clean_command)
        expect(output).to include('Deleting jobs: errand1')
        expect(output).to include('Succeeded')
      end
    end

    context 'when opting to keep orphaned disks' do
      let(:clean_command) { 'clean-up --all --keep-orphaned-disks' }

      it 'removes all artifacts except orphaned disks' do
        manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest_hash['name'] = 'deployment-a'
        manifest_hash['instance_groups'] = [
          SharedSupport::DeploymentManifestHelper.simple_instance_group(persistent_disk_type: 'disk_a', instances: 1, name: 'first-job'),
        ]
        cloud_config = SharedSupport::DeploymentManifestHelper.simple_cloud_config
        disk_type = SharedSupport::DeploymentManifestHelper.disk_type
        disk_type['cloud_properties'] = { 'my' => 'property' }
        cloud_config['disk_types'] = [disk_type]
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        bosh_runner.run('delete-deployment', deployment_name: 'deployment-a')
        bosh_runner.run(clean_command)

        clean_task_id = bosh_runner.get_most_recent_task_id
        cleanup_debug_logs = bosh_runner.run("task #{clean_task_id} --debug")
        expect(cleanup_debug_logs).to match(/Deleting dns blobs/)

        output = table(bosh_runner.run('releases', failure_expected: true, json: true))
        expect(output).to eq([])
        output = table(bosh_runner.run('stemcells', failure_expected: true, json: true))
        expect(output).to eq([])
        output = table(bosh_runner.run('disks --orphaned', failure_expected: true, json: true))
        expect(output).to_not eq([])
      end
    end
  end

  def upload_new_release_version(touched_file)
    Dir.chdir(IntegrationSupport::ClientSandbox.test_release_dir) do
      FileUtils.touch(File.join('src', 'bar', touched_file))
      bosh_runner.run_in_current_dir('create-release --force')
      bosh_runner.run_in_current_dir('upload-release')
    end
  end
end
