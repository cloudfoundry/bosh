require 'spec_helper'

describe Bosh::AwsCloud::StemcellCreator do

  let(:region) { double("region", :name => "us-east-1") }
  let(:stemcell_properties) do
    {
        "name" => "stemcell-name",
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
      Bosh::AwsCloud::ResourceWait.stub(:for_snapshot).with(snapshot: snapshot, state: :completed)
      Bosh::AwsCloud::ResourceWait.stub(:for_image).with(image: image, state: :available)
      region.stub_chain(:images, :create).and_return(image)

      creator.should_receive(:copy_root_image)
      volume.should_receive(:create_snapshot).and_return(snapshot)
      Bosh::AwsCloud::TagManager.should_receive(:tag).with(image, "Name", "stemcell-name 0.7.0")

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
      }.to raise_error Bosh::Clouds::CloudError, "Stemcell does not contain an AMI for this region (us-west-1)"

    end
  end

  describe "#image_params" do
    it "should construct correct image params" do
      params = described_class.new(region, stemcell_properties).image_params("id")

      params[:architecture].should == "x86_64"
      params[:description].should == "stemcell-name 0.7.0"
      params[:kernel_id].should == "aki-xxxxxxxx"
      params[:description].should == "stemcell-name 0.7.0"
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

  describe '#copy_root_image' do
    let(:creator) do
      creator = described_class.new(region, stemcell_properties)
      creator.stub(:image_path => '/path/to/image')
      creator.stub(:ebs_volume => '/dev/volume')
      creator
    end

    it 'should call stemcell-copy found in the PATH' do
      creator.stub(:find_in_path => '/path/to/stemcell-copy')
      result = double('result', :output => 'output')

      cmd = 'sudo -n /path/to/stemcell-copy /path/to/image /dev/volume 2>&1'
      creator.should_receive(:sh).with(cmd).and_return(result)

      creator.copy_root_image
    end

    it 'should call the bundled stemcell-copy if not found in the PATH' do
      creator.stub(:find_in_path => nil)
      result = double('result', :output => 'output')

      stemcell_copy = File.expand_path("../../../../bosh_aws_cpi/scripts/stemcell-copy.sh", __FILE__)
      cmd = "sudo -n #{stemcell_copy} /path/to/image /dev/volume 2>&1"
      creator.should_receive(:sh).with(cmd).and_return(result)

      creator.copy_root_image
    end
  end

end
