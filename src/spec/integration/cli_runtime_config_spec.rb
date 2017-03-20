require 'spec_helper'

describe "cli runtime config", type: :integration do
  with_reset_sandbox_before_each
  let(:client_env) { client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'} }

  it "can upload a runtime config" do
    target_and_login
    runtime_config = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.simple_runtime_config)
    expect(bosh_runner.run("update runtime-config #{runtime_config.path}")).to include("Successfully updated runtime config")
  end

  it "gives nice errors for common problems when uploading", no_reset: true do
    bosh_runner.run("target #{current_sandbox.director_url}")

    # not logged in
    expect(bosh_runner.run("update runtime-config some/path", failure_expected: true)).to include("Please log in first")

    bosh_runner.run("login test test")

    # no file
    expect(bosh_runner.run("update runtime-config /some/nonsense/file", failure_expected: true)).to include("Cannot find file '/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}", failure_expected: true)).to include("Incorrect YAML structure")
    end

    # empty runtime config file
    Dir.mktmpdir do |tmpdir|
      empty_runtime_config_filename = File.join(tmpdir, 'empty_runtime_config.yml')
      File.write(empty_runtime_config_filename, '')
      expect(bosh_runner.run("update cloud-config #{empty_runtime_config_filename}", failure_expected: true)).to include("Error 440001: Manifest should not be empty")
    end
  end

  it "can download a runtime config" do
    target_and_login

    # none present yet
    expect(bosh_runner.run("runtime-config")).to include("Acting as user 'test' on '#{current_sandbox.director_name}'\n")

    runtime_config = Bosh::Spec::Deployments.simple_runtime_config
    runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
    bosh_runner.run("update runtime-config #{runtime_config_file.path}")

    expect(bosh_runner.run("runtime-config")).to include(Psych.dump(runtime_config))
  end

  it "gives an error when release version is 'latest' on deploy" do
    target_and_login
    runtime_config = Bosh::Spec::Deployments.runtime_config_latest_release
    upload_runtime_config(runtime_config_hash: runtime_config, env: client_env)

    output, exit_code = deploy_from_scratch(no_login: true, env: client_env, failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
    expect(output).to include("Error 530001: Runtime " +
      "manifest contains the release 'bosh-release' with version as 'latest'. Please specify the actual version string.")
  end

  it "gives an error when release for addon does not exist in releases section" do
    target_and_login
    runtime_config = Bosh::Spec::Deployments.runtime_config_release_missing
    upload_runtime_config(runtime_config_hash: runtime_config, env: client_env)

    output, exit_code = deploy_from_scratch(no_login: true, env: client_env, failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
    expect(output).to include("Error 530002: " +
                                "Manifest specifies job 'job_using_pkg_2' which is defined in 'release2', but 'release2' is not listed in the runtime releases section.")
  end

  it 'does not fail when runtime config is very large' do
    target_and_login

    runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config)

    for i in 0..10001
      runtime_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
    end

    runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
    output, exit_code = bosh_runner.run("update runtime-config #{runtime_config_file.path}", return_exit_code: true)
    expect(output).to include('Successfully updated runtime config')
    expect(exit_code).to eq(0)
  end
end
