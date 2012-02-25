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

  it "should populate disk model" do
    config = YAML.load_file(spec_asset("test-bootstrap-config.yml"))
    config["dir"] = @dir
    Bosh::Deployer::Config.configure(config)
    disk_model = Bosh::Deployer::Config.disk_model
    disk_model.should == VSphereCloud::Models::Disk
    disk_model.columns.should include(:id)
    disk_model.count.should == 0
    cid = 22
    disk_model.insert({:id => cid, :size => 1024})
    disk_model.count.should == 1
    disk_model[cid].destroy
    disk_model.count.should == 0
  end
end
