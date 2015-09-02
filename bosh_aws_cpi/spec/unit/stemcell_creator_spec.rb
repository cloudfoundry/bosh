require 'spec_helper'

describe Bosh::AwsCloud::StemcellCreator do

  let(:region) { double("region", :name => "us-east-1") }
  let(:stemcell_properties) do
    {
        "name" => "stemcell-name",
        "version" => "0.7.0",
        "infrastructure" => "aws",
        "architecture" =>  "x86_64",
        "root_device_name" => "/dev/sda1",
        "virtualization_type" => virtualization_type
    }
  end

  let(:virtualization_type) { "paravirtual" }

  before do
    allow(Bosh::AwsCloud::AKIPicker).to receive(:new).and_return(double("aki", :pick => "aki-xxxxxxxx"))
  end

  context "real" do
    let(:volume) { double("volume") }
    let(:snapshot) { double("snapshot", :id => "snap-xxxxxxxx") }
    let(:image) { double("image") }
    let(:ebs_volume) { double("ebs_volume") }

    it "should create a real stemcell" do
      creator = described_class.new(region, stemcell_properties)
      allow(Bosh::AwsCloud::ResourceWait).to receive(:for_snapshot).with(snapshot: snapshot, state: :completed)
      allow(Bosh::AwsCloud::ResourceWait).to receive(:for_image).with(image: image, state: :available)
      allow(SecureRandom).to receive(:uuid).and_return("fake-uuid")
      allow(region).to receive_message_chain(:images, :create).and_return(image)

      expect(creator).to receive(:copy_root_image)
      expect(volume).to receive(:create_snapshot).and_return(snapshot)
      expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(image, "Name", "stemcell-name 0.7.0")

      creator.create(volume, ebs_volume, "/path/to/image")
    end
  end

  context "fake" do
    let(:stemcell_properties) do
      { "ami" => { "us-east-1" => "ami-xxxxxxxx" } }
    end

    it "should create a fake stemcell" do
      creator = described_class.new(region, stemcell_properties)

      expect(Bosh::AwsCloud::StemcellFinder).to receive(:find_by_region_and_id).with(region, "ami-xxxxxxxx light")
      creator.fake
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
    context "when the virtualization type is paravirtual" do
      let(:virtualization_type) { "paravirtual" }

      it "should construct correct image params" do
        params = described_class.new(region, stemcell_properties).image_params("id")

        expect(params[:architecture]).to eq("x86_64")
        expect(params[:description]).to eq("stemcell-name 0.7.0")
        expect(params[:kernel_id]).to eq("aki-xxxxxxxx")
        expect(params[:root_device_name]).to eq("/dev/sda1")
        expect(params[:block_device_mappings]).to eq({
          "/dev/sda"=>{:snapshot_id=>"id"},
          "/dev/sdb"=>"ephemeral0"
        })
      end
    end

    context "when the virtualization type is hvm" do
      let(:virtualization_type) { "hvm" }

      it "should construct correct image params" do
        params = described_class.new(region, stemcell_properties).image_params("id")

        expect(params[:architecture]).to eq("x86_64")
        expect(params[:description]).to eq("stemcell-name 0.7.0")
        expect(params).not_to have_key(:kernel_id)
        expect(params[:root_device_name]).to eq("/dev/xvda")
        expect(params[:sriov_net_support]).to eq("simple")
        expect(params[:block_device_mappings]).to eq({
          "/dev/xvda"=>{:snapshot_id=>"id"},
          "/dev/sdb"=>"ephemeral0"
        })
        expect(params[:virtualization_type]).to eq("hvm")
      end
    end
  end

  describe "#find_in_path" do
    it "should not find a missing file" do
      creator = described_class.new(region, stemcell_properties)
      expect(creator.find_in_path("program-that-doesnt-exist")).to be_nil
    end

    it "should find stemcell-copy" do
      creator = described_class.new(region, stemcell_properties)
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../assets', __FILE__)}"
      expect(creator.find_in_path("stemcell-copy", path)).to_not be_nil
    end
  end

  describe '#copy_root_image' do
    let(:creator) do
      creator = described_class.new(region, stemcell_properties)
      allow(creator).to receive(:image_path).and_return('/path/to/image')
      allow(creator).to receive(:ebs_volume).and_return('/dev/volume')
      creator
    end

    it 'should call stemcell-copy found in the PATH' do
      allow(creator).to receive(:find_in_path).and_return('/path/to/stemcell-copy')
      result = double('result', :output => 'output')

      cmd = 'sudo -n /path/to/stemcell-copy /path/to/image /dev/volume 2>&1'
      expect(creator).to receive(:sh).with(cmd).and_return(result)

      creator.copy_root_image
    end

    it 'should call the bundled stemcell-copy if not found in the PATH' do
      allow(creator).to receive(:find_in_path).and_return(nil)
      result = double('result', :output => 'output')

      stemcell_copy = File.expand_path("../../../../bosh_aws_cpi/scripts/stemcell-copy.sh", __FILE__)
      cmd = "sudo -n #{stemcell_copy} /path/to/image /dev/volume 2>&1"
      expect(creator).to receive(:sh).with(cmd).and_return(result)

      creator.copy_root_image
    end
  end
end
