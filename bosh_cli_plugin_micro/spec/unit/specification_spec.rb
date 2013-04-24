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
      spec.properties["ntp"].should == %w[1.2.3.4]
    end
  end

  describe 'compiled package cache' do
    it 'should update the apply spec if enabled in micro_bosh.yml apply_spec' do
      props = {
          "compiled_package_cache" => {
            "bucket" => "foo",
            "access_key_id" => "bar",
            "secret_access_key" => "baz"
        }
      }
      Bosh::Deployer::Config.stub(:agent_properties).and_return({})
      Bosh::Deployer::Config.stub(:spec_properties).and_return(props)

      spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)

      spec.update("1.1.1.1", "2.2.2.2")
      spec.properties["compiled_package_cache"].should == props["compiled_package_cache"]
    end
  end

  describe 'director ssl' do
    it 'updates the apply spec with ssl key and cert' do
      props = {
          "director" => {
            "ssl" => {
                "cert" => "foo-cert",
                "key" => "baz-key"
            }
          }
      }

      Bosh::Deployer::Config.stub(:agent_properties).and_return({})
      Bosh::Deployer::Config.stub(:spec_properties).and_return(props)

      spec = Bosh::Deployer::Specification.load_from_stemcell(spec_dir)

      spec.update("1.1.1.1", "2.2.2.2")
      spec.properties["ssl"].should == props["ssl"]
    end
  end
end