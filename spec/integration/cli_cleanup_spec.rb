require 'spec_helper'

describe 'cli: cleanup', type: :integration do
  with_reset_sandbox_before_each

  context 'cleanup' do
    it 'should remove releases and stemcells, leaving recent versions. Also leaves orphaned disks.' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['name'] = 'deployment-a'
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a', instances: 1, name: 'first-job')]
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      disk_pool = Bosh::Spec::Deployments.disk_pool
      disk_pool['cloud_properties'] = {'my' => 'property'}
      cloud_config['disk_pools'] = [disk_pool]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      upload_new_release_version('file-1.txt')
      upload_new_release_version('file-2.txt')

      disk_cid = director.instances[0].disk_cid

      bosh_runner.run('delete deployment deployment-a')
      bosh_runner.run('cleanup')
      expect(bosh_runner.run('disks --orphaned')).to include(disk_cid)

      releases_output = bosh_runner.run('releases')
      expect(releases_output).to_not include('0+dev.1')
      expect(releases_output).to include('0+dev.2')
      expect(releases_output).to include('0+dev.3')

      expect(bosh_runner.run('stemcells')).to include('ubuntu-stemcell')
    end
  end

  context 'cleanup --all' do
    it 'should remove orphaned disks, releases and stemcells' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['name'] = 'deployment-a'
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a', instances: 1, name: 'first-job')]
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      disk_pool = Bosh::Spec::Deployments.disk_pool
      disk_pool['cloud_properties'] = {'my' => 'property'}
      cloud_config['disk_pools'] = [disk_pool]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      bosh_runner.run('delete deployment deployment-a')

      bosh_runner.run('cleanup --all')

      expect(bosh_runner.run('releases', failure_expected: true)).to match_output('No releases')
      expect(bosh_runner.run('stemcells', failure_expected: true)).to match_output('No stemcells')
      expect(bosh_runner.run('disks --orphaned')).to match_output('No orphaned disks')
    end
  end

  def upload_new_release_version(touched_file)
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.touch(File.join('src', 'bar', touched_file))
      bosh_runner.run_in_current_dir('create release --force')
      bosh_runner.run_in_current_dir('upload release')
    end
  end
end
