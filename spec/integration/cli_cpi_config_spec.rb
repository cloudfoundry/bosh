require 'spec_helper'

describe "cli cpi config", type: :integration do
  with_reset_sandbox_before_each

  it "can upload a cpi config" do
    target_and_login
    Dir.mktmpdir do |tmpdir|
      cpi_config_filename = File.join(tmpdir, 'cpi_config.yml')
      File.write(cpi_config_filename, Psych.dump(Bosh::Spec::Deployments.simple_cpi_config))
      expect(bosh_runner.run("update cpi-config #{cpi_config_filename}")).to include("Successfully updated cpi config")
    end
  end

  it "gives nice errors for common problems when uploading", no_reset: true do
    bosh_runner.run("target #{current_sandbox.director_url}")

    # not logged in
    expect(bosh_runner.run("update cpi-config some/path", failure_expected: true)).to include("Please log in first")

    bosh_runner.run("login test test")

    # no file
    expect(bosh_runner.run("update cpi-config /some/nonsense/file", failure_expected: true)).to include("Cannot find file '/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      cpi_config_filename = File.join(tmpdir, 'cpi_config.yml')
      File.write(cpi_config_filename, "---\n}}}i'm not really yaml, hah!")
      expect(bosh_runner.run("update cpi-config #{cpi_config_filename}", failure_expected: true)).to include("Incorrect YAML structure")
    end

    # empty cpi config file
    Dir.mktmpdir do |tmpdir|
      empty_cpi_config_filename = File.join(tmpdir, 'empty_cpi_config.yml')
      File.write(empty_cpi_config_filename, '')
      expect(bosh_runner.run("update cloud-config #{empty_cpi_config_filename}", failure_expected: true)).to include("Error 440001: Manifest should not be empty")
    end
  end

  it "can download a cpi config" do
    target_and_login

    # none present yet
    expect(bosh_runner.run("cpi-config")).to include("Acting as user 'test' on 'Test Director'\n")

    Dir.mktmpdir do |tmpdir|
      cpi_config_filename = File.join(tmpdir, 'cpi_config.yml')
      cpi_config = Psych.dump(Bosh::Spec::Deployments.simple_cpi_config)
      File.write(cpi_config_filename, cpi_config)
      bosh_runner.run("update cpi-config #{cpi_config_filename}")

      expect(bosh_runner.run("cpi-config")).to include(cpi_config)
    end
  end

  it 'does not fail when cpi config is very large' do
    target_and_login

    Dir.mktmpdir do |tmpdir|
      cpi_config_filename = File.join(tmpdir, 'cpi_config.yml')
      cpi_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_cpi_config)

      for i in 0..10001
        cpi_config["boshbosh#{i}"] = 'smurfsAreBlueGargamelIsBrownPinkpantherIsPinkAndPikachuIsYellow'
      end

      cpi_config = Psych.dump(cpi_config)

      File.write(cpi_config_filename, cpi_config)
      output, exit_code = bosh_runner.run("update cpi-config #{cpi_config_filename}", return_exit_code: true)
      expect(output).to include('Successfully updated cpi config')
      expect(exit_code).to eq(0)
    end
  end
end
