require 'spec_helper'

describe "Director deprecating the 'template' syntax", type: :integration do
  with_reset_sandbox_before_each
  let(:manifest_hash) {
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['releases'].first['version'] = 'latest'
    manifest_hash['jobs'][0]['instances'] = 1
    manifest_hash
  }

  let(:cloud_config_hash) {
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['resource_pools'].first['size'] = 1
    cloud_config_hash
  }

  context 'when the manifest uses template with an array' do
    it 'issues a deprecation warning' do
      manifest_hash['jobs'][0]['template'] = [ 'foobar' ]
      expect(
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      ).to match(/Deprecation: .*soon be unsupported/)
    end
  end

  context 'when the manifest uses template with a string' do
    it 'does not issue a deprecation warning' do
      expect(
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
      ).to_not include('Deprecation')
    end
  end
end
