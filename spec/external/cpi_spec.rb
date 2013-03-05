# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"
require "tempfile"
require 'cloud'
require "bosh_aws_cpi"
require "bosh_aws_bootstrap/ec2"
require "bosh_aws_bootstrap/vpc"

describe Bosh::AwsCloud::Cloud do
  let(:cpi) do
    described_class.new(
        {
            "aws" => {
                "region" => "us-east-1",
                "default_key_name" => "bosh",
                "fast_path_delete" => "yes",
                "access_key_id" => ENV["BOSH_AWS_ACCESS_KEY_ID"],
                "secret_access_key" => ENV["BOSH_AWS_SECRET_ACCESS_KEY"],
            },
            "registry" => {
                "endpoint" => "fake",
                "user" => "fake",
                "password" => "fake"
            }
        }
    )
  end
  let(:ami) { "ami-809a48e9" }
  let(:ip) { "10.0.0.9" }
  let(:availability_zone) { "us-east-1d" }

  before do
    delegate = double("delegate", logger: double("logger").as_null_object)
    delegate.stub(:task_checkpoint)
    Bosh::Clouds::Config.configure(delegate)
    Bosh::AwsCloud::RegistryClient.stub(:new).and_return(double("registry").as_null_object)

    @instance_id = nil
    @volume_id = nil
  end

  after do
    cpi.delete_disk(@volume_id) if @volume_id
    cpi.delete_vm(@instance_id) if @instance_id

    if @vpc
      instance = @ec2.instances_for_ids([@instance_id]).first
      cpi.wait_resource(instance, :terminated)
      # wait_resource returns before the resource is freed. add sleep to ensure subnet has no more dependencies
      # and can be deleted safely
      sleep 8
      @vpc.delete_subnets
      @vpc.delete_vpc
    end
  end

  def vm_lifecycle(ami, network_spec, disk_locality)
    @instance_id = cpi.create_vm(
        "agent-007",
        ami,
        {"instance_type" => "m1.small"},
        network_spec,
        disk_locality,
        {"key" => "value"})

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
      {
          "default" => {
              "type" => "dynamic",
              "cloud_properties" => {}
          }
      }
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(ami, network_spec, [])
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
        vm_lifecycle(ami, network_spec, [@existing_volume_id])
      end
    end
  end

  describe "vpc" do
    let(:network_spec) do
      {
          "default" => {
              "type" => "manual",
              "ip" => ip,
              "cloud_properties" => {"subnet" => @subnet_id}
          }
      }
    end

    before do
      @ec2 = Bosh::Aws::EC2.new(access_key_id: ENV["BOSH_AWS_ACCESS_KEY_ID"], secret_access_key: ENV["BOSH_AWS_SECRET_ACCESS_KEY"])
      @vpc = Bosh::Aws::VPC.create(@ec2)

      subnet_configuration = {"vpc_subnet" => {"cidr" => "10.0.0.0/24", "availability_zone" => availability_zone}}
      @vpc.create_subnets(subnet_configuration)
      @subnet_id = @vpc.subnets.first[1]
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(ami, network_spec, [])
      end
    end
  end
end
