require 'spec_helper'

describe 'recreate_persistent_disks', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest) do
    manifest = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups(
      instances: 1,
    )
    manifest['instance_groups'].first['persistent_disk'] = 3000
    manifest
  end

  before do
    deploy_from_scratch(manifest_hash: manifest)
  end

  it 'recreates the persistent disk' do
    expect do
      deploy_simple_manifest(manifest_hash: manifest, recreate_persistent_disks: true)
    end.to change { orphaned_disks.length }.from(0).to(1)
  end
end
