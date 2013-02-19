require 'spec_helper'

describe Bosh::AwsCloud::StemcellCreator do

  let(:region) { double("region", :name => "us-east-1") }
  let(:stemcell_properties) do
    {
        "name" => "bosh-stemcell",
        "version" => "0.7.0",
        "infrastructure" => "aws",
        "architecture" =>  "x86_64",
        "root_device_name" => "/dev/sda1"
    }
  end

  before do
    Bosh::AwsCloud::AKIPicker.stub(:new => double("aki", :pick => "aki-xxxxxxxx"))
  end


  context "real" do
    let(:volume) { double("volume") }
    let(:snapshot) { double("snapshot", :id => "snap-xxxxxxxx") }
    let(:image) { double("image") }
    let(:ebs_volume) { double("ebs_volume") }

    it "should create a real stemcell" do
      creator = described_class.new(region, stemcell_properties)
      creator.stub(:wait_resource).with(snapshot, :completed)
      creator.stub(:wait_resource).with(image, :available, :state)
      region.stub_chain(:images, :create => image)

      creator.should_receive(:copy_root_image)
      volume.should_receive(:create_snapshot).and_return(snapshot)
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(image, "Name", "bosh-stemcell 0.7.0")

      stemcell = creator.create(volume, ebs_volume, "/path/to/image")
    end
  end

  context "fake" do
    let(:stemcell_properties) do
      { "ami" => { "us-east-1" => "ami-xxxxxxxx" } }
    end

    it "should create a fake stemcell" do
      creator = described_class.new(region, stemcell_properties)

      Bosh::AwsCloud::Stemcell.should_receive(:find).with(region, "ami-xxxxxxxx")
      stemcell = creator.fake
    end

    it "should raise an error if there is no ami for the current region" do
      region = double("region", :name => "us-west-1")
      creator = described_class.new(region, stemcell_properties)

      expect {
        creator.fake
      }.to raise_error Bosh::Clouds::CloudError, "Stemcell does not contain an AMI for this region"

    end
  end

  describe "#image_params" do
    it "should construct correct image params" do
      params = described_class.new(region, stemcell_properties).image_params("id")

      params[:architecture].should == "x86_64"
      params[:description].should == "bosh-stemcell 0.7.0"
      params[:kernel_id].should == "aki-xxxxxxxx"
      params[:description].should == "bosh-stemcell 0.7.0"
      params[:root_device_name].should == "/dev/sda1"
      params[:block_device_mappings].should == {
          "/dev/sda"=>{:snapshot_id=>"id"}, "/dev/sdb"=>"ephemeral0"
      }
    end
  end

  describe "#find_in_path" do
    it "should not find a missing file" do
      creator = described_class.new(region, stemcell_properties)
      creator.find_in_path("program-that-doesnt-exist").should be_nil
    end

    it "should find stemcell-copy" do
      creator = described_class.new(region, stemcell_properties)
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../assets', __FILE__)}"
      creator.find_in_path("stemcell-copy", path).should_not be_nil
    end
  end

end
