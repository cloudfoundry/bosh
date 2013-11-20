# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do
  let(:server) { double("server", :id => "i-test", :name => "i-test" ) }
  let(:volume) { double("volume", :id => "v-foobar", :server_id => nil) }
  let(:cloud)  {
    mock_cloud do |compute|
      compute.servers.should_receive(:get).with("i-test").and_return(server)
      compute.stub(:volumes).and_return([volume])
      compute.volumes.should_receive(:get).with("v-foobar").and_return(volume)
    end
  }

  before(:each) do
    @registry = mock_registry
  end

  it "attaches an CloudStack volume to a server" do
    job = generate_job
    job.should_receive(:job_result).and_return({"volume" => {"deviceid" => 2}})

    volume.should_receive(:attach).with(server).and_return(job)
    cloud.should_receive(:wait_job).with(job)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sdc"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end


  it "raises an error when sdc..sdz are all reserved" do
    job = generate_job
    job.should_receive(:job_result).and_return({"volume" => {"deviceid" => 100}})

    volume.should_receive(:attach).with(server).and_return(job)
    cloud.should_receive(:wait_job).with(job)

    expect {
      cloud.attach_disk("i-test", "v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

  it "bypasses the attaching process when volume is already attached to a server" do
    job = generate_job
    job.should_receive(:job_result).and_return({"volume" => {"deviceid" => 2}})

    volume.should_receive(:attach).with(server).and_return(job)
    cloud.should_receive(:wait_job).with(job)

    old_settings = { "foo" => "bar" }
    new_settings = {
        "foo" => "bar",
        "disks" => {
            "persistent" => {
                "v-foobar" => "/dev/sdc"
            }
        }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end

  it "should skip device_id: 3 and allign device file name" do
    job = generate_job
    job.should_receive(:job_result).and_return({"volume" => {"deviceid" => 5}})

    volume.should_receive(:attach).with(server).and_return(job)
    cloud.should_receive(:wait_job).with(job)

    old_settings = { "foo" => "bar" }
    new_settings = {
      "foo" => "bar",
      "disks" => {
        "persistent" => {
          "v-foobar" => "/dev/sde"
        }
      }
    }

    @registry.should_receive(:read_settings).with("i-test").and_return(old_settings)
    @registry.should_receive(:update_settings).with("i-test", new_settings)

    cloud.attach_disk("i-test", "v-foobar")
  end
end
