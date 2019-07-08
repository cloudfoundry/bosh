require_relative '../spec_helper'

describe 'cli: manifest', type: :integration do
  with_reset_sandbox_before_each

  it 'should return the same manifest that was submitted' do
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config

    deploy_from_scratch(manifest_file: 'manifests/manifest_with_yaml_boolean_values.yml', cloud_config_hash: cloud_config)
    manifest_output = bosh_runner.run('manifest', deployment_name: 'simple')

    expect(manifest_output).to match(File.open(spec_asset("manifests/manifest_with_yaml_boolean_values.yml")).read)

    #check that yaml 'boolean' values keep as "n" and "y"
    expect(manifest_output).to match(<<-OUT)
  properties:
    quote:
      "n": "yes"
      "y": "no"
    OUT
  end
end
