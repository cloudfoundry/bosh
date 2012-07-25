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

  it "resolves 'latest' release alias for multiple releases" do
    cmd = make_cmd
    manifest = {
      "name" => "mycloud",
      "director_uuid" => "deadbeef",
      "releases" => [
        {"name" => "foo", "version" => "latest"},
        {"name" => "bar", "version" => "latest"},
        {"name" => "baz", "version" => 3},
      ]
    }

    manifest_file = Tempfile.new("manifest")
    YAML.dump(manifest, manifest_file)
    manifest_file.close
    director = mock(Bosh::Cli::Director, :uuid => "deadbeef")

    cmd.stub!(:deployment).and_return(manifest_file.path)
    cmd.stub!(:director).and_return(director)

    releases = [
      {"name" => "foo", "versions" => %w(1 3.5.7-dev 2 3.5.2-dev)},
      {"name" => "bar", "versions" => %w(4 2 3 1 1.1-dev 3.99-dev)},
      {"name" => "baz", "versions" => %w(1 2 3 4 5 6 7)}
    ]

    director.should_receive(:list_releases).and_return(releases)

    manifest = cmd.prepare_deployment_manifest
    manifest["releases"][0]["version"].should == "3.5.7-dev"
    manifest["releases"][1]["version"].should == 4 # cast to Integer!
    manifest["releases"][2]["version"].should == 3
  end

  it "resolves 'latest' release alias for a single release" do
    cmd = make_cmd
    manifest = {
      "name" => "mycloud",
      "director_uuid" => "deadbeef",
      "release" => {"name" => "foo", "version" => "latest"}
    }

    manifest_file = Tempfile.new("manifest")
    YAML.dump(manifest, manifest_file)
    manifest_file.close
    director = mock(Bosh::Cli::Director, :uuid => "deadbeef")

    cmd.stub!(:deployment).and_return(manifest_file.path)
    cmd.stub!(:director).and_return(director)

    releases = [
      {"name" => "foo", "versions" => %w(1 3.5.7-dev 2 3.5.2-dev)},
    ]

    director.should_receive(:list_releases).and_return(releases)

    manifest = cmd.prepare_deployment_manifest
    manifest["release"]["version"].should == "3.5.7-dev"
  end

  it "treats having both 'releases' and 'release' as error" do
    cmd = make_cmd
    manifest = {
      "name" => "mycloud",
      "director_uuid" => "deadbeef",
      "release" => {"name" => "foo", "version" => "latest"},
      "releases" => []
    }

    manifest_file = Tempfile.new("manifest")
    YAML.dump(manifest, manifest_file)
    manifest_file.close
    director = mock(Bosh::Cli::Director, :uuid => "deadbeef")

    cmd.stub!(:deployment).and_return(manifest_file.path)
    cmd.stub!(:director).and_return(director)

    expect {
      cmd.prepare_deployment_manifest
    }.to raise_error(/manifest has both `release' and `releases'/i)
  end

end
