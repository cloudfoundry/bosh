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
      expect(ec2.instances).to receive(:[]).with("i-test").and_return(instance)
      expect(ec2.volumes).to receive(:[]).with("v-foobar").and_return(volume)
    end

    mappings = {
      "/dev/sdf" => double("attachment",
                         :volume => double("volume", :id => "v-foobar")),
      "/dev/sdg" => double("attachment",
                         :volume => double("volume", :id => "v-deadbeef")),
    }

    expect(instance).to receive(:block_device_mappings).and_return(mappings)

    expect(volume).to receive(:detach_from).
      with(instance, "/dev/sdf", force: false).and_return(attachment)

    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_attachment).with(attachment: attachment, state: :detached)

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

    expect(@registry).to receive(:read_settings).
      with("i-test").
      and_return(old_settings)

    expect(@registry).to receive(:update_settings).with("i-test", new_settings)

    cloud.detach_disk("i-test", "v-foobar")
  end

end
