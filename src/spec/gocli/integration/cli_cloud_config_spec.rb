  require_relative '../spec_helper'

describe 'cli cloud config', type: :integration do
  with_reset_sandbox_before_each

  context 'when cloud config uses placeholders' do
    it 'does not error' do
      cloud_config = yaml_file('cloud_config.yml', Bosh::Spec::Deployments.cloud_config_with_placeholders)
      expect(bosh_runner.run("update-cloud-config #{cloud_config.path}")).to include('Succeeded')
    end
  end

  it 'can upload a cloud config' do
    cloud_config = yaml_file('cloud_config.yml', Bosh::Spec::NewDeployments.simple_cloud_config)
    expect(bosh_runner.run("update-cloud-config #{cloud_config.path}")).to include('Succeeded')
  end

  it 'gives nice errors for common problems when uploading', no_reset: true do
    pending 'QUESTION Discuss correct behavior with Dmitriy on non-logged-in users and files that are not present'

    # not logged in
    expect(bosh_runner.run("update-cloud-config #{__FILE__}", include_credentials: false, failure_expected: true)).to include('Please log in first')

    # no file
    expect(bosh_runner.run('update-cloud-config /some/nonsense/file', failure_expected: true)).to include("Cannot find file '/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update-cloud-config #{cloud_config_filename}", failure_expected: true)).to include('Incorrect YAML structure')
    end

    # empty cloud config file
    Dir.mktmpdir do |tmpdir|
      empty_cloud_config_filename = File.join(tmpdir, 'empty_cloud_config.yml')
      File.write(empty_cloud_config_filename, '')
      expect(bosh_runner.run("update-cloud-config #{empty_cloud_config_filename}", failure_expected: true)).to include('Error 440001: Manifest should not be empty')
    end
  end

  context 'when an az is removed' do
    let(:initial_cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs }

    let(:new_cloud_config) do
      cloud_config = initial_cloud_config
      cloud_config['azs'].pop
      cloud_config['networks'][0]['subnets'].pop
      cloud_config
    end

    let(:initial_manifest) do
      manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest['instance_groups'][0]['azs'] = ['z1', 'z2']
      manifest
    end

    let(:new_manifest) do
      manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
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

    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_file = yaml_file('cloud_config.yml', cloud_config)
    bosh_runner.run("update-cloud-config #{cloud_config_file.path}")

    expect(YAML.load(bosh_runner.run('cloud-config', tty: false))).to eq(cloud_config)
  end

  it 'does not fail if the uploaded cloud config is a large file' do
    cloud_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::NewDeployments.simple_cloud_config)

    for i in 0..10001
      cloud_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
    end

    cloud_config_file = yaml_file('cloud_config.yml', cloud_config)

    output, exit_code = bosh_runner.run("update-cloud-config #{cloud_config_file.path}", return_exit_code: true)
    expect(output).to include('Succeeded')
    expect(exit_code).to eq(0)
  end
end
