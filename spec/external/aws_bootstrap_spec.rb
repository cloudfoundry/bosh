require "spec_helper"
require "cli"
require "bosh_aws_bootstrap"

describe 'bosh_aws_bootstrap_external' do
  include Bosh::Spec::CommandHelper

  let(:aws_params) do
    {
        :access_key_id => ENV["BOSH_AWS_ACCESS_KEY_ID"],
        :secret_access_key => ENV["BOSH_AWS_SECRET_ACCESS_KEY"],
        :ec2_endpoint => "ec2.us-east-1.amazonaws.com",
        :max_retries => 2
    }
  end

  let(:ec2) do
    AWS.config(aws_params)
    AWS::EC2.new
  end

  let(:aws_configuration_template) { File.join(File.dirname(__FILE__), '..','assets','aws','aws_configuration_template.yml.erb') }

  describe "VPC" do
    before(:all) { run_bosh "aws create vpc #{aws_configuration_template}" }
    after(:all) { run_bosh "aws destroy #{aws_configuration_template}" }

    it "builds the VPC" do
      ec2.vpcs.count.should == 1
    end

    it "builds the VPC subnets" do
      vpc = ec2.vpcs.first

      bosh_subnet = vpc.subnets.select { |subnet| subnet.cidr_block == "10.10.0.0/24" }.first
      bosh_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      bosh_subnet.instances.first.tags["Name"].should == "cf_nat_box"

      cf_subnet = vpc.subnets.select { |subnet| subnet.cidr_block == "10.10.1.0/24" }.first
      cf_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      cf_subnet.instances.count.should == 0

      cf_subnet_2 = vpc.subnets.select { |subnet| subnet.cidr_block == "10.10.2.0/24" }.first
      cf_subnet_2.availability_zone.name.should == ENV["BOSH_VPC_SECONDARY_AZ"]
      cf_subnet_2.instances.count.should == 0

      #TODO add tests for route table associations
    end

    pending "DHCP options"
    pending "security groups"
    pending "ELBs"
  end

  describe "Route53" do
    pending "should do something?"
  end

  describe "RDS" do
    #before(:all) { run_bosh "aws create rds #{aws_configuration_template}" }
    #after(:all) { run_bosh "aws destroy #{aws_configuration_template}" }

    it "can create and destroy an RDS configuration" do
    end
  end

  describe "S3" do
    #before(:all) { run_bosh "aws create s3 #{aws_configuration_template}" }
    #after(:all) { run_bosh "aws destroy #{aws_configuration_template}" }

    it "can create and destroy an S3 configuration" do
    end
  end

  describe "all resources" do
    it "can create and destroy a configuration of VPC, RDS, Route53, and S3" do
    end
  end
end