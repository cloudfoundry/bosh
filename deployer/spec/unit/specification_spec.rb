require "spec_helper"
describe Bosh::Deployer::Specification do

  let(:spec_dir) {File.dirname(spec_asset("apply_spec.yml"))}

  it "should load from file" do
    spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)
    spec.director_port.should == 25555
  end

  it "should update director address" do
    Bosh::Deployer::Config.stub(:agent_properties).and_return({})
    Bosh::Deployer::Config.stub(:spec_properties).and_return({})

    spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)
    spec.update("1.1.1.1", "2.2.2.2")
    spec.properties["director"]["address"].should == "2.2.2.2"
  end

  it "should update blobstore address" do
    Bosh::Deployer::Config.stub(:agent_properties).and_return({})
    Bosh::Deployer::Config.stub(:spec_properties).and_return({})

    spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)
    spec.update("1.1.1.1", "2.2.2.2")
    spec.properties["agent"]["blobstore"]["address"].should == "1.1.1.1"
  end

  describe "agent override" do
    it "should update blobstore address" do
      props = {"blobstore" => {"address" => "3.3.3.3"}}
      Bosh::Deployer::Config.stub(:agent_properties).and_return(props)
      Bosh::Deployer::Config.stub(:spec_properties).and_return({})

      spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)
      spec.update("1.1.1.1", "2.2.2.2")
      spec.properties["agent"]["blobstore"]["address"].should == "3.3.3.3"
    end

    it "should update ntp server list" do
      props = { "ntp" => %w[1.2.3.4] }
      Bosh::Deployer::Config.stub(:agent_properties).and_return({})
      Bosh::Deployer::Config.stub(:spec_properties).and_return(props)

      spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)
      spec.update("1.1.1.1", "2.2.2.2")
      spec.properties["agent"]["ntp"].should == %w[1.2.3.4]
    end
  end
end