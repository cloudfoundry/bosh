# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Config do
  before :each do
    @config    = File.join(Dir.mktmpdir, "bosh_config")
    @cache_dir = Dir.mktmpdir
  end

  def add_config(object)
    File.open(@config, "w") do |f|
      f.write(Psych.dump(object))
    end
  end

  def create_config
    Bosh::Cli::Config.new(@config)
  end

  it "should convert old deployment configs to the new config " +
     "when set_deployment is called" do
    add_config("target" => "localhost:8080", "deployment" => "test")

    cfg = create_config
    yaml_file = load_yaml_file(@config, nil)
    yaml_file["deployment"].should == "test"
    cfg.set_deployment("test2")
    cfg.save
    yaml_file = load_yaml_file(@config, nil)
    yaml_file["deployment"].has_key?("localhost:8080").should be(true)
    yaml_file["deployment"]["localhost:8080"].should == "test2"
  end

  it "should convert old deployment configs to the new config " +
     "when deployment is called" do
    add_config("target" => "localhost:8080", "deployment" => "test")

    cfg = create_config
    yaml_file = load_yaml_file(@config, nil)
    yaml_file["deployment"].should == "test"
    cfg.deployment.should == "test"
    yaml_file = load_yaml_file(@config, nil)
    yaml_file["deployment"].has_key?("localhost:8080").should be(true)
    yaml_file["deployment"]["localhost:8080"].should == "test"
  end

  it "should save a deployment for each target" do
    add_config({})
    cfg = create_config
    cfg.target = "localhost:1"
    cfg.set_deployment("/path/to/deploy/1")
    cfg.save
    cfg.target = "localhost:2"
    cfg.set_deployment("/path/to/deploy/2")
    cfg.save

    # Test that the file is written correctly.
    yaml_file = load_yaml_file(@config, nil)
    yaml_file["deployment"].has_key?("localhost:1").should be(true)
    yaml_file["deployment"].has_key?("localhost:2").should be(true)
    yaml_file["deployment"]["localhost:1"].should == "/path/to/deploy/1"
    yaml_file["deployment"]["localhost:2"].should == "/path/to/deploy/2"

    # Test that switching targets gives you the new deployment.
    cfg.deployment.should == "/path/to/deploy/2"
    cfg.target = "localhost:1"
    cfg.deployment.should == "/path/to/deploy/1"
  end

  it "returns nil when the deployments key exists but has no value" do
    add_config("target" => "localhost:8080", "deployment" => nil)

    cfg = create_config
    yaml_file = load_yaml_file(@config, nil)
    yaml_file["deployment"].should == nil
    cfg.deployment.should == nil
  end

  it "should throw MissingTarget when getting deployment without target set" do
    add_config({})
    cfg = create_config
    expect { cfg.set_deployment("/path/to/deploy/1") }.
        to raise_error(Bosh::Cli::MissingTarget)
  end

  it "whines on missing config file" do
    lambda {
      File.should_receive(:open).with(@config, "w").and_raise(Errno::EACCES)
      create_config
    }.should raise_error(Bosh::Cli::ConfigError)
  end


  it "effectively ignores config file if it is malformed" do
    add_config([1, 2, 3])
    cfg = create_config

    cfg.target.should == nil
  end

  it "fetches auth information from the config file" do
    config = {
      "target" => "localhost:8080",
      "deployment" => "test",
      "auth" => {
        "localhost:8080" => { "username" => "a", "password" => "b" },
        "localhost:8081" => { "username" => "c", "password" => "d" }
      }
    }

    add_config(config)
    cfg = create_config

    cfg.username("localhost:8080").should == "a"
    cfg.password("localhost:8080").should == "b"

    cfg.username("localhost:8081").should == "c"
    cfg.password("localhost:8081").should == "d"

    cfg.username("localhost:8083").should be_nil
    cfg.password("localhost:8083").should be_nil
  end

end
