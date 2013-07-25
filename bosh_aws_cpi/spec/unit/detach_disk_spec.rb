# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it "detaches EC2 volume from an instance" do
    instance = double("instance", :id => "i-test")
    volume = double("volume", :id => "v-foobar")
    attachment = double("attachment", :device => "/dev/sdf")

    cloud = mock_cloud do |ec2|
      ec2.instances.should_receive(:[]).with("i-test").and_return(instance)
      ec2.volumes.should_receive(:[]).with("v-foobar").and_return(volume)
    end

    mappings = {
      "/dev/sdf" => double("attachment",
                         :volume => double("volume", :id => "v-foobar")),
      "/dev/sdg" => double("attachment",
                         :volume => double("volume", :id => "v-deadbeef")),
    }

    instance.should_receive(:block_device_mappings).and_return(mappings)

    volume.should_receive(:detach_from).
      with(instance, "/dev/sdf", force: false).and_return(attachment)

    Bosh::AwsCloud::ResourceWait.stub(:for_attachment).with(attachment: attachment, state: :detached)

    old_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdf",
          "v-deadbeef" => "/dev/sdg"
        }
      }
    }

    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-deadbeef" => "/dev/sdg"
        }
      }
    }

    @registry.should_receive(:read_settings).
      with("i-test").
      and_return(old_settings)

    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-foobar")
  end

end
