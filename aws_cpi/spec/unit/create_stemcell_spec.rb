# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "EBS-volume based flow" do

    it "creates stemcell by copying an image to a new EBS volume" do
      volume = double("volume", :id => "v-foo")
      current_instance = double("instance",
                                :id => "i-current",
                                :availability_zone => "us-nowhere-2b")
      attachment = double("attachment",
                          :device => "/dev/sdh",
                          :volume => volume)

      snapshot = double("snapshot", :id => "s-baz")
      image = double("image", :id => "i-bar")

      unique_name = UUIDTools::UUID.random_create.to_s

      image_params = {
        :name => "BOSH-#{unique_name}",
        :architecture => "x86_64",
        :kernel_id => "aki-825ea7eb",
        :root_device_name => "/dev/sda",
        :block_device_mappings => {
          "/dev/sda" => { :snapshot_id => "s-baz" },
          "/dev/sdb" => "ephemeral0"
        }
      }

      cloud = mock_cloud do |ec2|
        ec2.volumes.stub(:[]).with("v-foo").and_return(volume)
        ec2.instances.stub(:[]).with("i-current").and_return(current_instance)
        ec2.images.should_receive(:create).with(image_params).and_return(image)
      end

      cloud.stub(:generate_unique_name).and_return(unique_name)
      cloud.stub(:current_instance_id).and_return("i-current")

      old_mappings = {
        "/dev/sdf" => double("attachment",
                             :volume => double("volume",
                                               :id => "v-zb")),
        "/dev/sdg" => double("attachment",
                             :volume => double("volume",
                                               :id => "v-ppc"))
      }

      extra_mapping = {
        "/dev/sdh" => attachment
      }

      new_mappings = old_mappings.merge(extra_mapping)

      current_instance.stub(:block_device_mappings).
        and_return(old_mappings, new_mappings)

      cloud.should_receive(:create_disk).with(2048, "i-current").
        and_return("v-foo")

      volume.should_receive(:attach_to).with(current_instance, "/dev/sdh").
        and_return(attachment)

      cloud.should_receive(:wait_resource).with(attachment, :attached)

      cloud.stub(:sleep)

      File.stub(:blockdev?).with("/dev/sdh").and_return(false, false, false)
      File.stub(:blockdev?).with("/dev/xvdh").and_return(false, false, true)

      cloud.should_receive(:copy_root_image).with("/tmp/foo", "/dev/xvdh")

      volume.should_receive(:create_snapshot).and_return(snapshot)
      cloud.should_receive(:wait_resource).with(snapshot, :completed)

      cloud.should_receive(:wait_resource).with(image, :available, :state)

      volume.should_receive(:detach_from).with(current_instance, "/dev/sdh").
        and_return(attachment)

      cloud.should_receive(:wait_resource).with(attachment, :detached)

      cloud.should_receive(:delete_disk).with("v-foo")

      cloud.create_stemcell("/tmp/foo", {}).should == "i-bar"
    end

  end
end
