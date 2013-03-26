# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"
require "tempfile"
require 'cloud'
require "bosh_aws_cpi"
require "bosh_aws_bootstrap/ec2"
require "bosh_aws_bootstrap/vpc"

describe Bosh::AwsCloud::Cloud do
  let(:cpi_options) do
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
  end

  let(:cpi) { described_class.new(cpi_options) }
  let(:ami) { "ami-809a48e9" }
  let(:ip) { "10.0.0.9" }
  let(:availability_zone) { "us-east-1d" }
  let(:ec2) do
    Bosh::Aws::EC2.new(
        access_key_id: ENV["BOSH_AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["BOSH_AWS_SECRET_ACCESS_KEY"]
    )
  end

  before do
    delegate = double("delegate", logger: Logger.new(STDOUT))
    delegate.stub(:task_checkpoint)
    Bosh::Clouds::Config.configure(delegate)
    Bosh::AwsCloud::RegistryClient.stub(:new).and_return(double("registry").as_null_object)

    @instance_id = nil
    @volume_id = nil
    ec2.force_add_key_pair(
        cpi_options["aws"]["default_key_name"],
        ENV["GLOBAL_BOSH_KEY_PATH"]
    )
  end

  after do
    cpi.delete_disk(@volume_id) if @volume_id
    if @instance_id
      cpi.delete_vm(@instance_id)

      instance = ec2.instances_for_ids([@instance_id]).first
      ::Bosh::AwsCloud::ResourceWait.for_instance(instance: instance, state: :terminated)

      cpi.has_vm?(@instance_id).should be_false
    end

    if @vpc
      # this returns before the resource is freed. add sleep to ensure subnet has no more dependencies
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

    cpi.has_vm?(@instance_id).should be_true

    vm_metadata = {:job => "cpi_spec", :index => "0"}
    cpi.set_vm_metadata(@instance_id, vm_metadata)

    @volume_id = cpi.create_disk(2048, @instance_id)
    @volume_id.should_not be_nil

    cpi.attach_disk(@instance_id, @volume_id)
    # can attempt to detach before API consistently finishes attaching
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
      @vpc = Bosh::Aws::VPC.create(ec2)
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
