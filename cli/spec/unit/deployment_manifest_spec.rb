# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::DeploymentHelper do

  def make_cmd(options = {})
    cmd = Bosh::Cli::Command::Base.new(options)
    cmd.extend(Bosh::Cli::DeploymentHelper)
    cmd
  end

  it "checks that actual director UUID matches the one in manifest" do
    cmd = make_cmd
    manifest = {
      "name" => "mycloud",
      "director_uuid" => "deadbeef"
    }

    manifest_file = Tempfile.new("manifest")
    YAML.dump(manifest, manifest_file)
    manifest_file.close
    director = mock(Bosh::Cli::Director)

    cmd.stub!(:deployment).and_return(manifest_file.path)
    cmd.stub!(:director).and_return(director)

    director.should_receive(:uuid).and_return("deadcafe")

    expect {
      cmd.prepare_deployment_manifest
    }.to raise_error(/Target director UUID doesn't match/i)
  end

end
