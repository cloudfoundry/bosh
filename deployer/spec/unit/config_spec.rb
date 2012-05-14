# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Deployer::Config do
  before(:each) do
    @dir = Dir.mktmpdir("bdc_spec")
  end

  after(:each) do
    FileUtils.remove_entry_secure @dir
  end

  it "configure should fail without cloud properties" do
    lambda {
      Bosh::Deployer::Config.configure({"dir" => @dir})
    }.should raise_error(Bosh::Deployer::ConfigError)
  end

  it "should default agent properties" do
    config = YAML.load_file(spec_asset("test-bootstrap-config.yml"))
    config["dir"] = @dir
    Bosh::Deployer::Config.configure(config)

    properties = Bosh::Deployer::Config.cloud_options["properties"]
    properties["agent"].should be_kind_of(Hash)
    properties["agent"]["mbus"].start_with?("http://").should be_true
    properties["agent"]["blobstore"].should be_kind_of(Hash)
  end

  it "should map network properties" do
    config = YAML.load_file(spec_asset("test-bootstrap-config.yml"))
    config["dir"] = @dir
    Bosh::Deployer::Config.configure(config)

    networks = Bosh::Deployer::Config.networks
    networks.should be_kind_of(Hash)

    net = networks['bosh']
    net.should be_kind_of(Hash)
    ['cloud_properties', 'netmask', 'gateway', 'ip', 'dns', 'default'].each do |key|
      net[key].should_not be_nil
    end
  end

  it "should default vm env properties" do
    env = Bosh::Deployer::Config.env
    env.should be_kind_of(Hash)
    env.should have_key("bosh")
    env["bosh"].should be_kind_of(Hash)
    env["bosh"]["password"].should be_nil
  end

  it "should contain default vm resource properties" do
    Bosh::Deployer::Config.configure({"dir" => @dir, "cloud" => { "plugin" => "vsphere" }})
    resources = Bosh::Deployer::Config.resources
    resources.should be_kind_of(Hash)

    resources['persistent_disk'].should be_kind_of(Integer)

    cloud_properties = resources['cloud_properties']
    cloud_properties.should be_kind_of(Hash)

    ['ram', 'disk', 'cpu'].each do |key|
      cloud_properties[key].should_not be_nil
      cloud_properties[key].should be > 0
    end
  end

  it "should configure agent using mbus property" do
    config = YAML.load_file(spec_asset("test-bootstrap-config.yml"))
    config["dir"] = @dir
    Bosh::Deployer::Config.configure(config)
    agent = Bosh::Deployer::Config.agent
    agent.should be_kind_of(Bosh::Agent::HTTPClient)
  end
end
