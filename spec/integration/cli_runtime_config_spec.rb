require 'spec_helper'

describe "cli runtime config", type: :integration do
  with_reset_sandbox_before_each

  it "can upload a runtime config" do
    target_and_login
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.simple_runtime_config))
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}")).to include("Successfully updated runtime config")
    end
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
    expect(bosh_runner.run("runtime-config")).to include("Acting as user 'test' on 'Test Director'\n")

    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      runtime_config = Psych.dump(Bosh::Spec::Deployments.simple_runtime_config)
      File.write(runtime_config_filename, runtime_config)
      bosh_runner.run("update runtime-config #{runtime_config_filename}")

      expect(bosh_runner.run("runtime-config")).to include(runtime_config)
    end
  end

  it "gives an error when release version is 'latest'" do
    target_and_login
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_latest_release))
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}", failure_expected: true)).to include("Error 530001: Runtime " +
        "manifest contains the release 'test_release_2' with version as 'latest'. Please specify the actual version string.")
    end
  end

  it "gives an error when release for addon does not exist in releases section" do
    target_and_login
    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      File.write(runtime_config_filename, Psych.dump(Bosh::Spec::Deployments.runtime_config_release_missing))
      expect(bosh_runner.run("update runtime-config #{runtime_config_filename}", failure_expected: true)).to include("Error 530002: Runtime " +
        "manifest specifies job 'job_using_pkg_2' which is defined in 'release2', but 'release2' is not listed in the releases section.")
    end
  end

  it 'does not fail when runtime config is very large' do
    target_and_login

    Dir.mktmpdir do |tmpdir|
      runtime_config_filename = File.join(tmpdir, 'runtime_config.yml')
      runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config)

      for i in 0..10001
        runtime_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      runtime_config = Psych.dump(runtime_config)

      File.write(runtime_config_filename, runtime_config)
      output, exit_code = bosh_runner.run("update runtime-config #{runtime_config_filename}", return_exit_code: true)
      expect(output).to include('Successfully updated runtime config')
      expect(exit_code).to eq(0)
    end
  end
end
