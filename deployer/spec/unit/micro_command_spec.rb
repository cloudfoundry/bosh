# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Cli::Command::Base do

  before :each do
    @config = File.join(Dir.mktmpdir, "bosh_config")
    @cache = File.join(Dir.mktmpdir, "bosh_cache")
    @opts = { :config => @config, :cache_dir => @cache }
  end

  describe Bosh::Cli::Command::Micro do

    before :each do
      @cmd = Bosh::Cli::Command::Micro.new(@opts)
      @cmd.stub!(:interactive?).and_return(false)
      @manifest_path = spec_asset("deployment.MF")
      @manifest_yaml = { "name" => "foo", "cloud" => {} }
      @manifest_yaml["resources"] = { "persistent_disk" => 16384 }
    end

    it "allows deploying a micro BOSH instance passing stemcell as argument" do
      mock_deployer = mock(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:create_deployment).with("stemcell.tgz")
      mock_stemcell = mock(Bosh::Cli::Stemcell)
      mock_stemcell.should_receive(:validate)
      mock_stemcell.should_receive(:valid?).and_return(true)

      @cmd.stub!(:deployment).and_return(@manifest_path)
      @manifest_yaml["cloud"] = { "properties" => { "stemcell" => {"image_id" => "sc-id" } } }
      @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
      @cmd.stub!(:target_name).and_return("micro-test")
      Bosh::Cli::Stemcell.should_receive(:new).and_return(mock_stemcell)
      @cmd.stub!(:deployer).and_return(mock_deployer)
      @cmd.perform("stemcell.tgz")
    end

    it "allows deploying a micro BOSH instance passing stemcell in manifest file" do
      mock_deployer = mock(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:create_deployment).with("sc-id")

      @cmd.stub!(:deployment).and_return(@manifest_path)
      @cmd.stub!(:target_name).and_return("micro-test")
      @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
      @manifest_yaml["cloud"] = { "properties" => { "stemcell" => {"image_id" => "sc-id" } } }
      @cmd.stub!(:deployer).and_return(mock_deployer)
      @cmd.perform()
    end

    it "should not allow deploying a micro BOSH instance if no stemcell is provided" do
      lambda {
        @cmd.stub!(:deployment).and_return(@manifest_path)
        @manifest_yaml = { "name" => "foo" }
        @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
        @cmd.perform()
      }.should raise_error(Bosh::Cli::CliExit, "No stemcell provided")
    end

    it "should require a persistent disk" do
      lambda {
        mock_deployer = mock(Bosh::Deployer::InstanceManager)
        mock_deployer.should_receive(:exists?).exactly(1).times

        @cmd.stub!(:deployment).and_return(@manifest_path)
        @cmd.stub!(:target_name).and_return("micro-test")
        @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
        @manifest_yaml["cloud"] = { "properties" => { "stemcell" => {"image_id" => "sc-id" } } }
        @manifest_yaml["resources"] = {}
        @cmd.stub!(:deployer).and_return(mock_deployer)
        @cmd.perform()
      }.should raise_error(Bosh::Cli::CliExit, "No persistent disk configured!")
    end

  end

end