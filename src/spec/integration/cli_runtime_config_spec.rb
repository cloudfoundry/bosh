require_relative '../spec_helper'

describe 'cli runtime config', type: :integration do
  with_reset_sandbox_before_each
  let(:un_named_rc) { Bosh::Spec::Deployments.simple_runtime_config }
  let(:named_rc_1) do
    rc = Bosh::Spec::Deployments.simple_runtime_config
    rc['releases'][0] = { 'name' => 'named_rc_1', 'version' => '1' }
    rc
  end

  let(:named_rc_2) do
    rc = Bosh::Spec::Deployments.simple_runtime_config
    rc['releases'][0] = { 'name' => 'named_rc_2', 'version' => '1' }
    rc
  end

  it 'can upload a default (unnamed) runtime config' do
    runtime_config = yaml_file('runtime_config.yml', un_named_rc)
    expect(bosh_runner.run("update-runtime-config #{runtime_config.path}")).to include('Succeeded')
  end

  it 'can upload a named runtime config' do
    named_runtime_config_file_1 = yaml_file('runtime_config.yml', named_rc_1)
    named_runtime_config_file_2 = yaml_file('runtime_config.yml', named_rc_2)
    expect(bosh_runner.run("update-runtime-config --name=named_rc_1 #{named_runtime_config_file_1.path}")).to include('Succeeded')
    expect(bosh_runner.run("update-runtime-config --name=named_rc_2 #{named_runtime_config_file_2.path}")).to include('Succeeded')
  end

  it 'can download a default runtime config' do
    expect(bosh_runner.run('runtime-config', failure_expected: true)).to match(/Using environment 'https:\/\/127\.0\.0\.1:\d+' as client 'test'/)

    default_runtime_config_file = yaml_file('runtime_config.yml', un_named_rc)
    named_runtime_config_file_1 = yaml_file('runtime_config.yml', named_rc_1)
    named_runtime_config_file_2 = yaml_file('runtime_config.yml', named_rc_2)

    bosh_runner.run("update-runtime-config #{default_runtime_config_file.path}")
    bosh_runner.run("update-runtime-config --name=named_rc_1 #{named_runtime_config_file_1.path}")
    bosh_runner.run("update-runtime-config --name=named_rc_2 #{named_runtime_config_file_2.path}")

    expect(YAML.safe_load(bosh_runner.run('runtime-config', tty: false), permitted_classes: [Symbol], permitted_symbols:[], aliases: true)).to eq(un_named_rc)
  end

  it 'can download a named runtime config' do
    expect(bosh_runner.run('runtime-config', failure_expected: true)).to match(/Using environment 'https:\/\/127\.0\.0\.1:\d+' as client 'test'/)

    default_runtime_config_file = yaml_file('runtime_config.yml', un_named_rc)
    named_runtime_config_file_1 = yaml_file('runtime_config.yml', named_rc_1)
    named_runtime_config_file_2 = yaml_file('runtime_config.yml', named_rc_2)

    bosh_runner.run("update-runtime-config #{default_runtime_config_file.path}")
    bosh_runner.run("update-runtime-config --name=named_rc_1 #{named_runtime_config_file_1.path}")
    bosh_runner.run("update-runtime-config --name=named_rc_2  #{named_runtime_config_file_2.path}")

    expect(YAML.safe_load(bosh_runner.run('runtime-config --name=named_rc_1', tty: false), permitted_classes: [Symbol], permitted_symbols:[], aliases: true)).to eq(named_rc_1)
    expect(YAML.safe_load(bosh_runner.run('runtime-config --name=named_rc_2', tty: false), permitted_classes: [Symbol], permitted_symbols:[], aliases: true)).to eq(named_rc_2)
  end

  it 'downloads the latest version of each runtime config' do
    expect(bosh_runner.run('runtime-config', failure_expected: true)).to match(/Using environment 'https:\/\/127\.0\.0\.1:\d+' as client 'test'/)

    bosh_runner.run("update-runtime-config #{yaml_file('runtime_config.yml', un_named_rc).path}")
    bosh_runner.run("update-runtime-config --name=named_rc_1 #{yaml_file('runtime_config.yml', named_rc_1).path}")
    bosh_runner.run("update-runtime-config --name=named_rc_2 #{yaml_file('runtime_config.yml', named_rc_2).path}")

    un_named_rc_v2 = { 'releases' => [{ 'name' => 'test_release_10', 'version' => '10' }] }
    named_rc_1_v2 = { 'releases' => [{ 'name' => 'test_release_20', 'version' => '20' }] }

    bosh_runner.run("update-runtime-config #{yaml_file('runtime_config.yml', un_named_rc_v2).path}")
    bosh_runner.run("update-runtime-config --name=named_rc_1 #{yaml_file('runtime_config.yml', named_rc_1_v2).path}")

    expect(YAML.safe_load(bosh_runner.run('runtime-config', tty: false), permitted_classes: [Symbol], permitted_symbols:[], aliases: true)).to eq(un_named_rc_v2)
    expect(
      YAML.safe_load(
        bosh_runner.run('runtime-config --name=named_rc_1', tty: false),
        permitted_classes: [Symbol], permitted_symbols:[], aliases: true,
      ),
    ).to eq(named_rc_1_v2)
    expect(YAML.safe_load(bosh_runner.run('runtime-config --name=named_rc_2', tty: false), permitted_classes: [Symbol], permitted_symbols:[], aliases: true)).to eq(named_rc_2)
  end

  it "gives an error when release version is 'latest'" do
    runtime_config = Bosh::Spec::Deployments.simple_runtime_config('bosh-release', 'latest')
    upload_runtime_config(runtime_config_hash: runtime_config)
    output, exit_code = deploy_from_scratch(
      manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
      cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      failure_expected: true,
      return_exit_code: true,
    )

    expect(exit_code).to_not eq(0)
    expect(output).to include(
      "Runtime manifest contains the release 'bosh-release' with version as 'latest'. Please specify the actual version string.",
    )
  end

  it 'gives an error when release for addon does not exist in releases section' do
    runtime_config = Bosh::Spec::Deployments.runtime_config_release_missing

    upload_runtime_config(runtime_config_hash: runtime_config)
    output, exit_code = deploy_from_scratch(
      manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
      cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config,
      failure_expected: true,
      return_exit_code: true,
    )

    expect(exit_code).to_not eq(0)
    expect(output).to include("Manifest specifies job 'job_using_pkg_2' which is defined in 'release2', but 'release2' is not listed in the runtime releases section.")
  end

  it 'does not fail when runtime config is very large' do
    runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config)

    (0..10_001).each do |i|
      runtime_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
    end

    runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
    output, exit_code = bosh_runner.run("update-runtime-config #{runtime_config_file.path}", return_exit_code: true)
    expect(output).to include('Succeeded')
    expect(exit_code).to eq(0)
  end

  it 'uploads runtime config that can be seen by the generic config commands' do
    runtime_config = yaml_file('runtime_config.yml', un_named_rc)
    bosh_runner.run("update-runtime-config #{runtime_config.path}")

    output = JSON.parse(bosh_runner.run('configs --type=runtime --json'))

    configs = output['Tables'].first['Rows']

    expect(configs.count).to eq 1
    expect(configs.first).to include('name' => 'default', 'type' => 'runtime', 'team' => '')
  end

  it 'shows no diff when uploading same unnamed runtime config as with generic config command' do
    runtime_config = yaml_file('runtime_config.yml', un_named_rc)
    bosh_runner.run("update-config --name=default --type=runtime #{runtime_config.path}")
    output = bosh_runner.run("update-runtime-config #{runtime_config.path}")
    expect(output).to match(/Using environment 'https:\/\/.+' as client 'test'\n\nSucceeded/)
  end
end
