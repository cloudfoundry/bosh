require 'spec_helper'

describe 'when the deployment manifest file is large', type: :integration do
  with_reset_sandbox_before_each

  let(:deployment_manifest) do
    minimal_manifest = Bosh::Common::DeepCopy.copy(Bosh::Spec::DeploymentManifestHelper.minimal_manifest)
    minimal_manifest['foobar'] = {}
    (0..100_000).each do |i|
      minimal_manifest['foobar']["property#{i}"] = "value#{i}"
    end

    yaml_file('minimal', minimal_manifest)
  end

  before do
    release_filename = asset_path('test_release.tgz')
    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)

    bosh_runner.run("upload-release #{release_filename}")
    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}")
    bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
  end

  it 'deploys successfully' do
    bosh_runner.run("deploy -d minimal #{deployment_manifest.path}")
  end
end
