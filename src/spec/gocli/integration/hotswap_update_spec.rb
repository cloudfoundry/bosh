require_relative '../spec_helper'
require 'fileutils'

describe 'deploy with hotswap', type: :integration do
  context 'a very simple deploy' do
    with_reset_sandbox_before_each

    let(:manifest) do
      manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups(instances: 1)
      manifest['update'] = manifest['update'].merge({'strategy' => 'hot-swap'})
      manifest
    end

    before do
      cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config['networks'][0]['type'] = 'dynamic'

      manifest['instance_groups'][0]['networks'][0].delete('static_ips')
      deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: manifest, recreate: true)
    end

    it 'should create vms that require recreation and download packages to them before updating' do
      output = bosh_runner.run("task 4")

      expect(output).to match(/Creating missing vms: foobar\/.*\n.*Downloading packages: foobar.*\n.*Updating instance foobar/)
    end
  end
end
