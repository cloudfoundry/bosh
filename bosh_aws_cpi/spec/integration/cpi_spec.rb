# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

require "tempfile"

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    unless ENV["EC2_ACCESS_KEY"] && ENV["EC2_SECRET_KEY"]
      pending "please provide access_key_id and secret_access_key"
    end
    @config = YAML.load_file(asset("config.yml"))
    @config["aws"]["access_key_id"] = ENV["EC2_ACCESS_KEY"]
    @config["aws"]["secret_access_key"] = ENV["EC2_SECRET_KEY"]

    @logger = Logger.new("/dev/null")
    Bosh::Clouds::Config.stub(:logger => @logger)
  end

  let(:cpi) do
    cpi = Bosh::AwsCloud::Cloud.new(@config)
    cpi.logger = @logger
    cpi.stub(:registry => double("registry").as_null_object)

    cpi
  end

  before(:each) do
    @instance_id = nil
    @volume_id = nil
  end

  after(:each) do
    cpi.delete_disk(@volume_id) if @volume_id
    cpi.delete_vm(@instance_id) if @instance_id
  end

  def vm_lifecycle(ami, network_spec, disk_locality)
    @instance_id = cpi.create_vm(
      "agent-007",
      ami,
      { "instance_type" => "m1.small" },
      network_spec,
      disk_locality,
      { "key" => "value" })

    @instance_id.should_not be_nil

    vm_metadata = {:job => "cpi_spec", :index => "0"}
    cpi.set_vm_metadata(@instance_id, vm_metadata)

    @volume_id = cpi.create_disk(2048, @instance_id)
    @volume_id.should_not be_nil

    cpi.attach_disk(@instance_id, @volume_id)
    cpi.detach_disk(@instance_id, @volume_id)
  end

  describe "ec2" do
    let(:network_spec) do
      { "default" => {
          "type" => "dynamic",
          "cloud_properties" => {}
        }
      }
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(@config["ami"], network_spec, [])
      end
    end

    context "with existing disks" do
      before do
        @existing_volume_id = cpi.create_disk(2048)
      end

      after do
        cpi.delete_disk(@existing_volume_id) if @existing_volume_id
      end

      it "should exercise the vm lifecycle" do
        vm_lifecycle(@config["ami"], network_spec, [@existing_volume_id])
      end
    end
  end

  describe "vpc" do
    let(:network_spec) do
      {
          "default" => {
              "type" => "manual",
              "ip" => @config["ip"],
              "cloud_properties" => {"subnet" => @config["subnet"]}
          }
      }

    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(@config["ami"], network_spec, [])
      end
    end

  end

end
