# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Cli::Command::Base do

  before :each do
    @config = File.join(Dir.mktmpdir, "bosh_config")
    @cache = File.join(Dir.mktmpdir, "bosh_cache")
  end

  describe Bosh::Cli::Command::Micro do

    before :each do
      @cmd = Bosh::Cli::Command::Micro.new(nil)
      @cmd.add_option(:non_interactive, true)
      @cmd.add_option(:config, @config)
      @cmd.add_option(:cache_dir, @cache)
      @manifest_path = spec_asset("deployment.MF")
      @manifest_yaml = {"name" => "foo", "cloud" => {}}
      @manifest_yaml["resources"] = {
          "persistent_disk" => 16384,
          "cloud_properties" => {}
      }
    end

    it "allows deploying a micro BOSH instance passing stemcell as argument" do
      mock_deployer = mock(Bosh::Deployer::InstanceManager)
      mock_deployer.should_receive(:exists?).exactly(2).times
      mock_deployer.should_receive(:renderer=)
      mock_deployer.should_receive(:check_dependencies)
      mock_deployer.should_receive(:create_deployment).with("stemcell.tgz")
      mock_stemcell = mock(Bosh::Cli::Stemcell)
      mock_stemcell.should_receive(:validate)
      mock_stemcell.should_receive(:valid?).and_return(true)

      @cmd.stub!(:deployment).and_return(@manifest_path)
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
      mock_deployer.should_receive(:check_dependencies)
      mock_deployer.should_receive(:create_deployment).with("sc-id")

      @cmd.stub!(:deployment).and_return(@manifest_path)
      @cmd.stub!(:target_name).and_return("micro-test")
      @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
      @manifest_yaml["resources"]["cloud_properties"]["image_id"] = "sc-id"
      @cmd.stub!(:deployer).and_return(mock_deployer)
      @cmd.perform()
    end

    it "should not allow deploying a micro BOSH instance if no stemcell is provided" do
      expect {
        @cmd.stub!(:deployment).and_return(@manifest_path)
        @manifest_yaml = {"name" => "foo"}
        @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
        @cmd.perform()
      }.to raise_error(Bosh::Cli::CliError, "No stemcell provided")
    end

    it "should require a persistent disk" do
      file = Bosh::Cli::Command::Micro::MICRO_BOSH_YAML
      error_message = "No persistent disk configured in #{file}"
      expect {
        mock_deployer = mock(Bosh::Deployer::InstanceManager)
        mock_deployer.should_receive(:check_dependencies)
        mock_deployer.should_receive(:exists?).exactly(1).times

        @cmd.stub!(:deployment).and_return(@manifest_path)
        @cmd.stub!(:target_name).and_return("micro-test")
        @cmd.stub!(:load_yaml_file).and_return(@manifest_yaml)
        @manifest_yaml["resources"]["cloud_properties"]["image_id"] = "sc-id"
        @manifest_yaml["resources"]["persistent_disk"] = nil
        @cmd.stub!(:deployer).and_return(mock_deployer)
        @cmd.perform()
      }.to raise_error(Bosh::Cli::CliExit, error_message)
    end

    it "should clear cached target values when setting a new deployment" do
      @cmd.stub(:find_deployment).with("foo").and_return(spec_asset("test-bootstrap-config-aws.yml"))
      @cmd.stub_chain(:deployer, :discover_bosh_ip).and_return(nil)

      config = double("config", :target => "target", :resolve_alias => nil, :set_deployment => nil)

      config.should_receive(:target=).with("http://foo:25555")
      config.should_receive(:target_name=).with(nil)
      config.should_receive(:target_version=).with(nil)
      config.should_receive(:target_uuid=).with(nil)
      config.should_receive(:save)

      @cmd.stub(:config).and_return(config)

      @cmd.set_current("foo")
    end

    it "should create the defined directory in deployments directory when initializing a new deployment for vcloud" do
      execute_init_test_for "vcloud"
    end

    it "should create the defined directory in deployments directory when initializing a new deployment for vsphere" do
      execute_init_test_for "vsphere"
    end

    def execute_init_test_for(cloud_provider)
      user_defined_dir = "cloud"
      expected_directory = "./deployments/#{user_defined_dir}"
      File.stub!(:exists?).with("./deployments/#{user_defined_dir}").and_return(false)
      FileUtils.stub!(:mkdir).with(expected_directory)
      FileUtils.stub!(:cp).with(include("/config/templates/micro_bosh_#{cloud_provider}.yml"), "#{expected_directory}/micro_bosh.yml")
      @cmd.init user_defined_dir, cloud_provider
    end

    it "should raise an error if the user defined directory exists in deployments directory" do
      user_defined_dir = "cloud"
      expected_directory = "./deployments/#{user_defined_dir}"
      File.stub!(:exists?).with(expected_directory).and_return(true)
      expect {
        @cmd.init user_defined_dir, "vcloud"
      }.to raise_error(Bosh::Cli::CliError, "#{expected_directory} already exists")
    end

    it "should raise an error if an incorrect cloud provider is entered" do
      expect {
        @cmd.init :user_defined_dir, "whatever"
      }.to raise_error(Bosh::Cli::CliError, 'whatever not a recognized cloud provider type. cloud_provider_type arg Must be one of: vcloud vsphere')
    end


  end

end
