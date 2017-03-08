require_relative '../spec_helper'

describe 'cli: cleanup', type: :integration do
  with_reset_sandbox_before_each

  shared_examples_for 'removing an ephemeral blob' do
    before {
      bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.minimal_legacy_manifest)
      bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'minimal_legacy_manifest')

      bosh_runner.run("export-release test_release/1 toronto-os/1", deployment_name: 'minimal_legacy_manifest')
      bosh_runner.run("export-release test_release/1 centos-7/3001", deployment_name: 'minimal_legacy_manifest')
    }

    it 'should clean up compiled ephemeral blobs of compiled releases' do
      output = bosh_runner.run(clean_command)

      expect(output).to include('Deleting ephemeral blobs')
      expect(output.scan(/Deleting ephemeral blobs/).count).to eq(2)
      expect(output).to include('Succeeded')
    end
  end

  context 'clean-up' do
    let(:clean_command) { 'clean-up' }

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

      disk_cid = director.instances(deployment_name: 'deployment-a')[0].disk_cids[0]

      bosh_runner.run('delete-deployment', deployment_name: 'deployment-a')

      bosh_runner.run(clean_command)

      expect(table(bosh_runner.run('disks --orphaned', json: true))[0]['disk_cid']).to eq(disk_cid)

      releases_output = table(bosh_runner.run('releases', json: true))
      release_versions = releases_output.map{|r| r['version']}
      expect(release_versions).to_not include('0+dev.1')
      expect(release_versions).to include('0+dev.2')
      expect(release_versions).to include('0+dev.3')

      stemcell_output = table(bosh_runner.run('stemcells', json: true ))
      stemcells = stemcell_output.map{|r| r['name']}
      expect(stemcells).to include('ubuntu-stemcell')
      expect(stemcells.length).to eq(1)
    end

    context 'when there are compiled releases in the blobstore' do
      include_examples 'removing an ephemeral blob'
    end
  end

  context 'clean-up --all' do
    let(:clean_command) { 'clean-up --all' }

    it 'should remove orphaned disks, releases and stemcells' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['name'] = 'deployment-a'
      manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a', instances: 1, name: 'first-job')]
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      disk_pool = Bosh::Spec::Deployments.disk_pool
      disk_pool['cloud_properties'] = {'my' => 'property'}
      cloud_config['disk_pools'] = [disk_pool]
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

      bosh_runner.run('delete-deployment', deployment_name: 'deployment-a')

      bosh_runner.run(clean_command)

      output = table(bosh_runner.run('releases', failure_expected: true, json: true))
      expect(output).to eq([])
      output = table(bosh_runner.run('stemcells', failure_expected: true, json: true))
      expect(output).to eq([])
      output = table(bosh_runner.run('disks --orphaned', failure_expected: true, json: true))
      expect(output).to eq([])
    end

    context 'when there are compiled releases in the blobstore' do
      include_examples 'removing an ephemeral blob'
    end
  end

  def upload_new_release_version(touched_file)
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.touch(File.join('src', 'bar', touched_file))
      bosh_runner.run_in_current_dir('create-release --force')
      bosh_runner.run_in_current_dir('upload-release')
    end
  end
end
