# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do
  before { @tmp_dir = Dir.mktmpdir }
  after { FileUtils.rm_rf(@tmp_dir) }

  describe "EBS-volume based flow" do
    let(:creator) { double(Bosh::AwsCloud::StemcellCreator) }

    before { Bosh::AwsCloud::StemcellCreator.stub(:new => creator) }

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
        creator.should_receive(:fake?).and_return(true)
        creator.should_receive(:fake).and_return(double("ami", :id => "ami-xxxxxxxx"))
        cloud.create_stemcell("/tmp/foo", stemcell_properties).should == "ami-xxxxxxxx"
      end
    end

    context "real stemcell" do
      let(:stemcell_properties) do
        {
          "root_device_name" => "/dev/sda1",
          "architecture" => "x86_64",
          "name" => "stemcell-name",
          "version" => "1.2.3"
        }
      end

      let(:volume) { double("volume", :id => "vol-xxxxxxxx") }
      let(:stemcell) { double("stemcell", :id => "ami-xxxxxxxx") }
      let(:instance) { double("instance") }

      it "should create a stemcell" do
        cloud = mock_cloud do |ec2|
          ec2.volumes.stub(:[]).with("vol-xxxxxxxx").and_return(volume)
          ec2.instances.stub(:[]).with("i-xxxxxxxx").and_return(instance)
        end

        creator.should_receive(:fake?).and_return(false)
        creator.should_not_receive(:fake)

        cloud.should_receive(:current_vm_id).twice.and_return("i-xxxxxxxx")

        cloud.should_receive(:create_disk).with(2048, "i-xxxxxxxx").and_return("vol-xxxxxxxx")
        cloud.should_receive(:attach_ebs_volume).with(instance, volume).and_return("/dev/sdh")
        cloud.should_receive(:find_ebs_device).with("/dev/sdh").and_return("ebs")

        creator.should_receive(:create).with(volume, "ebs", "/tmp/foo").and_return(stemcell)

        cloud.should_receive(:detach_ebs_volume).with(instance, volume, true)
        cloud.should_receive(:delete_disk).with("vol-xxxxxxxx")

        cloud.create_stemcell("/tmp/foo", stemcell_properties).should == "ami-xxxxxxxx"
      end
    end

    describe "#find_ebs_device" do
      it "should locate ebs volume on the current instance and return the device name" do
        cloud = mock_cloud

        File.stub(:blockdev?).with("/dev/sdf").and_return(true)

        cloud.find_ebs_device("/dev/sdf").should == "/dev/sdf"
      end

      it "should locate ebs volume on the current instance and return the virtual device name" do
        cloud = mock_cloud

        File.stub(:blockdev?).with("/dev/sdf").and_return(false)
        File.stub(:blockdev?).with("/dev/xvdf").and_return(true)

        cloud.find_ebs_device("/dev/sdf").should == "/dev/xvdf"
      end
    end
  end
end
