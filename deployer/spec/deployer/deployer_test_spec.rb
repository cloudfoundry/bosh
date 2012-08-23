# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Deployer do

  def setup(config_yml)
    @stemcell_tgz = ENV['BOSH_STEMCELL_TGZ']
    @dir = ENV['BOSH_DEPLOYER_DIR'] || Dir.mktmpdir("bd_spec")
    config = YAML.load_file(spec_asset(config_yml))
    config["dir"] = @dir
    @deployer = Bosh::Deployer::InstanceManager.new(config)
  end

  after(:all) do
    FileUtils.remove_entry_secure @dir unless ENV['BOSH_DEPLOYER_DIR']
  end

  describe "vSphere" do
    before(:all) do
      setup("test-bootstrap-config.yml")
    end

    it "should access vSphere cloud" do
      @deployer.cloud.should be_kind_of(Bosh::Clouds::VSphere)
    end

    it "should create a Bosh VM" do
      pending "stemcell tgz" unless @stemcell_tgz
      @deployer.create(@stemcell_tgz)
    end

    it "should respond to agent ping" do
      pending "VM cid" unless @deployer.state.vm_cid
      @deployer.agent.ping.should == "pong"
    end

    it "should destroy the Bosh deployment" do
      pending "VM cid" unless @deployer.state.vm_cid
      @deployer.destroy
      @deployer.state.disk_cid.should be_nil
    end
  end

  describe "aws" do
    before(:all) do
      setup("test-bootstrap-config-aws.yml")
    end

    it "should instantiate a deployer" do
      @deployer.cloud.should be_kind_of(Bosh::AwsCloud::Cloud)
    end
  end
end
