require 'spec_helper'

describe "Director deprecating the 'template' syntax", type: :integration do
  with_reset_sandbox_before_each

  context 'when the manifest uses template with an array' do
    it 'issues a deprecation warning' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0].delete('template')
      manifest_hash['jobs'][0]['template'] = [ 'foobar' ]
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['resource_pools'][0]['size'] = 1
      output = deploy_simple(manifest_hash: manifest_hash)
      expect(output).to match(/Deprecation: .*soon be unsupported/)
    end
  end

  context 'when the manifest uses template with a string' do
    it 'is chill' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['resource_pools'][0]['size'] = 1
      output = deploy_simple(manifest_hash: manifest_hash)
      expect(output).to_not include('deprecated')
    end
  end
end
