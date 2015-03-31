require 'spec_helper'

describe "cli cloud config", type: :integration do
  with_reset_sandbox_before_each

  it "can upload a cloud config" do
    bosh_runner.run("target #{current_sandbox.director_url}")
    bosh_runner.run("login admin admin")
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, "---\nfoo: bar")
      expect(bosh_runner.run("update cloud-config #{cloud_config_filename}")).to include("Successfully updated cloud config")
    end
  end

  it "gives nice errors for common problems", no_reset: true do
    bosh_runner.run("target #{current_sandbox.director_url}")

    # not logged in
    expect(bosh_runner.run("update cloud-config some/path", failure_expected: true)).to include("Please log in first")

    bosh_runner.run("login admin admin")

    # no file
    expect(bosh_runner.run("update cloud-config /some/nonsense/file", failure_expected: true)).to include("Cannot find file `/some/nonsense/file'")

    # file not yaml
    Dir.mktmpdir do |tmpdir|
      cloud_config_filename = File.join(tmpdir, 'cloud_config.yml')
      File.write(cloud_config_filename, "i'm not really yaml, hah!")
      expect(bosh_runner.run("update cloud-config #{cloud_config_filename}", failure_expected: true)).to include("Incorrect YAML structure")
    end
  end
end
