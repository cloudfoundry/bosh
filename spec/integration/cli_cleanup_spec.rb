require 'spec_helper'

describe 'cli: cleanup', type: :integration do
  with_reset_sandbox_before_each

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

      expect(bosh_runner.run('releases', failure_expected: true)).to include('No releases')
      expect(bosh_runner.run('stemcells', failure_expected: true)).to include('No stemcells')
      expect(bosh_runner.run('disks --orphaned')).to include('No orphaned disks')
    end
  end
end
