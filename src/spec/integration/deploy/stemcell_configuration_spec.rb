require 'spec_helper'

describe 'stemcell configuration', type: :integration do
  with_reset_sandbox_before_each

  context 'when stemcell is specified with an OS' do
    it 'deploys with the stemcell with specified OS and version' do
      create_and_upload_test_release

      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
      stemcell_id = current_sandbox.cpi.all_stemcells[0]['id']

      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_v2.tgz')}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['stemcells'].first.delete('name')
      manifest_hash['stemcells'].first['os'] = 'toronto-os'
      manifest_hash['stemcells'].first['version'] = '1'
      manifest_hash['instance_groups'].first['instances'] = 1
      deploy_simple_manifest(manifest_hash: manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(create_vm_invocations.count).to be_positive

      create_vm_invocations.each do |invocation|
        expect(invocation['inputs']['stemcell_id']).to eq(stemcell_id)
      end
    end
  end

  context 'when an update-deploy that also changes a stemcell' do
    before do
      create_and_upload_test_release

      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_v2.tgz')}")

      stemcell_v1_manifest = Bosh::Common::DeepCopy.copy(manifest_hash)
      stemcell_v1_manifest['stemcells'].first['version'] = '1'
      deploy_simple_manifest(manifest_hash: stemcell_v1_manifest)
    end

    let(:manifest_hash) do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['stemcells'].first.delete('name')
      manifest_hash['stemcells'].first['os'] = 'toronto-os'
      manifest_hash['stemcells'].first['version'] = '2'
      deploy_simple_manifest(manifest_hash: manifest_hash)
      manifest_hash['instance_groups'].first['instances'] = 1
      manifest_hash
    end

    context 'when the deployment fails' do
      before do
        current_sandbox.cpi.commands.make_create_vm_always_fail
      end

      it 'does not change the stemcell' do
        deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
        current_versions = table(bosh_runner.run('stemcells', json: true)).map { |s| s['version'] }
        expect(current_versions).to contain_exactly('1*', '2*')
      end
    end

    context 'when the deployment succeeds' do
      it 'does change the stemcell' do
        deploy_simple_manifest(manifest_hash: manifest_hash)
        current_versions = table(bosh_runner.run('stemcells', json: true)).map { |s| s['version'] }
        expect(current_versions).to contain_exactly('1', '2*')
      end
    end

    context 'when there is a stopped instance during the update' do
      let(:manifest_hash) do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
        manifest_hash['stemcells'].first.delete('name')
        manifest_hash['stemcells'].first['os'] = 'toronto-os'
        manifest_hash['stemcells'].first['version'] = '2'
        deploy_simple_manifest(manifest_hash: manifest_hash)
        manifest_hash
      end

      it 'also upgrades the stopped instance to the new stemcell when it is restarted' do
        bosh_runner.run('stop foobar/0', deployment_name: 'simple')
        bosh_runner.run('stop --hard foobar/1', deployment_name: 'simple')
        deploy_simple_manifest(manifest_hash: manifest_hash)
        bosh_runner.run('start foobar/0', deployment_name: 'simple')
        bosh_runner.run('start foobar/1', deployment_name: 'simple')

        current_versions = table(bosh_runner.run('stemcells', json: true)).map { |s| s['version'] }
        expect(current_versions).to contain_exactly('1', '2*')
      end
    end
  end

  context 'when stemcell is using latest version' do
    it 'redeploys with latest version of stemcell' do
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
      manifest_hash['stemcells'].first['version'] = 'latest'
      manifest_hash['instance_groups'].first['instances'] = 1

      create_and_upload_test_release
      upload_cloud_config(cloud_config_hash: cloud_config)

      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
      stemcell1 = table(bosh_runner.run('stemcells', json: true)).last
      expect(stemcell1['version']).to eq('1')

      deploy_simple_manifest(manifest_hash: manifest_hash)
      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      initial_count = invocations.count
      expect(initial_count).to be > 1
      expect(invocations.last['inputs']['stemcell_id']).to eq(stemcell1['cid'])

      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_v2.tgz')}")
      stemcell2 = table(bosh_runner.run('stemcells', json: true)).first
      expect(stemcell2['version']).to eq('2')

      deploy_simple_manifest(manifest_hash: manifest_hash)
      invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(invocations.count).to be > initial_count
      expect(invocations.last['inputs']['stemcell_id']).to eq(stemcell2['cid'])
    end
  end
end
