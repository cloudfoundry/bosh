require_relative '../spec_helper'

describe "Director deprecating the 'template' syntax", type: :integration do
  with_reset_sandbox_before_each
  let(:manifest_hash) {
    manifest_hash = Bosh::Spec::Deployments.legacy_manifest
    manifest_hash['jobs'][0]['instances'] = 1
    manifest_hash
  }

  context 'when the manifest uses template with an array' do
    it 'issues a deprecation warning' do
      manifest_hash['jobs'][0].delete('templates')
      manifest_hash['jobs'][0]['template'] = [ 'foobar' ]
      expect(
        deploy_from_scratch(manifest_hash: manifest_hash)
      ).to match(/Deprecation:.*template.*soon be unsupported/)
    end
  end

  context 'when the manifest uses template with a string' do
    it 'does not issue a deprecation warning' do
      expect(
        deploy_from_scratch(manifest_hash: manifest_hash)
      ).to_not match(/Deprecation:.*template.*soon be unsupported/)
    end
  end
end
