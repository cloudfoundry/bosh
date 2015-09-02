# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do
  before { @tmp_dir = Dir.mktmpdir }
  after { FileUtils.rm_rf(@tmp_dir) }

  describe "EBS-volume based flow" do
    let(:creator) { double(Bosh::AwsCloud::StemcellCreator) }

    before { allow(Bosh::AwsCloud::StemcellCreator).to receive(:new).and_return(creator) }

    context "fake stemcell" do
      let(:stemcell_properties) do
        {
          "root_device_name" => "/dev/sda1",
          "architecture" => "x86_64",
          "name" => "stemcell-name",
          "version" => "1.2.3",
          "ami" => {
            "us-east-1" => "ami-xxxxxxxx"
          }
        }
      end

      it "should return a fake stemcell" do
        cloud = mock_cloud
        expect(creator).to receive(:fake?).and_return(true)
        expect(creator).to receive(:fake).and_return(double("ami", :id => "ami-xxxxxxxx"))
        expect(cloud.create_stemcell("/tmp/foo", stemcell_properties)).to eq("ami-xxxxxxxx")
      end
    end

    context "real stemcell" do
      let(:stemcell_properties) do
        {
          "root_device_name" => "/dev/sda1",
          "architecture" => "x86_64",
          "name" => "stemcell-name",
          "version" => "1.2.3",
          "virtualization_type" => "paravirtual"
        }
      end

      let(:volume) { double("volume", :id => "vol-xxxxxxxx") }
      let(:stemcell) { double("stemcell", :id => "ami-xxxxxxxx") }
      let(:instance) { double("instance") }

      it "should create a stemcell" do
        cloud = mock_cloud do |ec2|
          allow(ec2.volumes).to receive(:[]).with("vol-xxxxxxxx").and_return(volume)
          allow(ec2.instances).to receive(:[]).with("i-xxxxxxxx").and_return(instance)
        end

        expect(creator).to receive(:fake?).and_return(false)
        expect(creator).not_to receive(:fake)

        expect(cloud).to receive(:current_vm_id).twice.and_return("i-xxxxxxxx")

        expect(cloud).to receive(:create_disk).with(2048, {}, "i-xxxxxxxx").and_return("vol-xxxxxxxx")
        expect(cloud).to receive(:attach_ebs_volume).with(instance, volume).and_return("/dev/sdh")
        expect(cloud).to receive(:find_ebs_device).with("/dev/sdh").and_return("ebs")

        expect(creator).to receive(:create).with(volume, "ebs", "/tmp/foo").and_return(stemcell)

        expect(cloud).to receive(:detach_ebs_volume).with(instance, volume, true)
        expect(cloud).to receive(:delete_disk).with("vol-xxxxxxxx")

        expect(cloud.create_stemcell("/tmp/foo", stemcell_properties)).to eq("ami-xxxxxxxx")
      end
    end

    describe "#find_ebs_device" do
      it "should locate ebs volume on the current instance and return the device name" do
        cloud = mock_cloud

        allow(File).to receive(:blockdev?).with("/dev/sdf").and_return(true)

        expect(cloud.find_ebs_device("/dev/sdf")).to eq("/dev/sdf")
      end

      it "should locate ebs volume on the current instance and return the virtual device name" do
        cloud = mock_cloud

        allow(File).to receive(:blockdev?).with("/dev/sdf").and_return(false)
        allow(File).to receive(:blockdev?).with("/dev/xvdf").and_return(true)

        expect(cloud.find_ebs_device("/dev/sdf")).to eq("/dev/xvdf")
      end
    end
  end
end
