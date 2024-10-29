  require 'spec_helper'

describe 'cli cloud config', type: :integration do
  with_reset_sandbox_before_each

  context 'when cloud config uses placeholders' do
    it 'does not error' do
      cloud_config = yaml_file('cloud_config.yml', Bosh::Spec::DeploymentManifestHelper.cloud_config_with_placeholders)
      expect(bosh_runner.run("update-cloud-config #{cloud_config.path}")).to include('Succeeded')
    end
  end

  it 'can upload a cloud config' do
    cloud_config = yaml_file('cloud_config.yml', Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
    expect(bosh_runner.run("update-cloud-config #{cloud_config.path}")).to include('Succeeded')
  end

  context 'when an az is removed' do
    let(:initial_cloud_config) { Bosh::Spec::DeploymentManifestHelper.simple_cloud_config_with_multiple_azs }

    let(:new_cloud_config) do
      cloud_config = initial_cloud_config
      cloud_config['azs'].pop
      cloud_config['networks'][0]['subnets'].pop
      cloud_config
    end

    let(:initial_manifest) do
      manifest = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest['instance_groups'][0]['azs'] = ['z1', 'z2']
      manifest
    end

    let(:new_manifest) do
      manifest = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
      manifest['instance_groups'][0]['azs'] = ['z1']
      manifest
    end

    it 'successfully deploys' do
      create_and_upload_test_release
      upload_cloud_config(cloud_config_hash: initial_cloud_config)
      upload_stemcell
      deploy_simple_manifest(manifest_hash: initial_manifest)

      upload_cloud_config(cloud_config_hash: new_cloud_config)
      expect{ deploy_simple_manifest(manifest_hash: new_manifest) }.to_not raise_error
    end
  end

  it 'can download a cloud config' do
    # none present yet
    expect(bosh_runner.run('cloud-config', failure_expected: true)).to match(/Using environment 'https:\/\/127\.0\.0\.1:\d+' as client 'test'/)

    cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
    cloud_config_file = yaml_file('cloud_config.yml', cloud_config)
    bosh_runner.run("update-cloud-config #{cloud_config_file.path}")

    expect(YAML.load(bosh_runner.run('cloud-config', tty: false))).to eq(cloud_config)
  end

  it 'does not fail if the uploaded cloud config is a large file' do
    cloud_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)

    (0..10001).each { |i|
      cloud_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
    }

    cloud_config_file = yaml_file('cloud_config.yml', cloud_config)

    output, exit_code = bosh_runner.run("update-cloud-config #{cloud_config_file.path}", return_exit_code: true)
    expect(output).to include('Succeeded')
    expect(exit_code).to eq(0)
  end
end
