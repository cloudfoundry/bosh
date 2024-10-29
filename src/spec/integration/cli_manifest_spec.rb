require 'spec_helper'

describe 'cli: manifest', type: :integration do
  with_reset_sandbox_before_each

  it 'should return the same manifest that was submitted' do
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config

    deploy_from_scratch(manifest_file: 'manifests/manifest_with_yaml_boolean_values.yml', cloud_config_hash: cloud_config)
    manifest_output = bosh_runner.run('manifest', deployment_name: 'simple')

    expect(manifest_output).to match(File.open(asset_path("manifests/manifest_with_yaml_boolean_values.yml")).read)
  end
end
