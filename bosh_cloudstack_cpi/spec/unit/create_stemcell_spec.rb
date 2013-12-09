# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do
  before { @tmp_dir = Dir.mktmpdir }
  after { FileUtils.rm_rf(@tmp_dir) }

  describe "Volume based flow" do
    let(:creator) { double(Bosh::CloudStackCloud::StemcellCreator) }

    before { Bosh::CloudStackCloud::StemcellCreator.stub(:new => creator) }

    context "real stemcell" do
      let(:stemcell_properties) do
        {
          "root_device_name" => "/dev/sda1",
          "architecture" => "x86_64",
          "name" => "stemcell-name",
          "version" => "1.2.3"
        }
      end

      let(:volume) { double("volume", :id => "vol-xxxxxxxx", :reload => true, :server_id => nil) }
      let(:stemcell) { double("stemcell", :id => "ami-xxxxxxxx", :zone_name => 'foobar-1a', :zone_id => 'foobar-1a') }
      let(:server) { double("server", :id => "s-xxxxxxxx") }

      it "should create a stemcell" do
        cloud = mock_cloud do |compute|
          compute.volumes.stub(:get).with("vol-xxxxxxxx").and_return(volume)
          compute.volumes.stub(:find).and_return(nil)
          compute.servers.stub(:get).with("s-xxxxxxxx").and_return(server)
        end

        cloud.should_receive(:current_vm_id).twice.and_return("s-xxxxxxxx")

        cloud.should_receive(:create_disk).with(10240, "s-xxxxxxxx").and_return("vol-xxxxxxxx")
        cloud.should_receive(:attach_volume).with(server, volume).and_return("/dev/sdh")
        cloud.should_receive(:find_volume_device).with("/dev/sdh").and_return("/dev/vdh")

        creator.should_receive(:create).with(volume, "/dev/vdh", "/tmp/foo").and_return(stemcell)
        stemcell.should_receive(:copy)
        cloud.stub(:wait_job)

        cloud.should_receive(:detach_volume).with(server, volume)
        cloud.should_receive(:delete_disk).with("vol-xxxxxxxx")

        cloud.create_stemcell("/tmp/foo", stemcell_properties).should == "ami-xxxxxxxx"
      end
    end

    describe "#find_volume_device" do
      it "should locate volume on the current instance and return the device name" do
        cloud = mock_cloud

        File.stub(:blockdev?).with("/dev/sdf").and_return(true)

        cloud.find_volume_device("/dev/sdf").should == "/dev/sdf"
      end

      it "should locate volume on the current instance and return the virtual device name" do
        cloud = mock_cloud

        File.stub(:blockdev?).with("/dev/sdf").and_return(false)
        File.stub(:blockdev?).with("/dev/vdf").and_return(true)

        cloud.find_volume_device("/dev/sdf").should == "/dev/vdf"
      end
    end
  end
end
