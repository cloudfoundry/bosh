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
    let(:vpc) { ec2.vpcs.first }
    let(:bosh_subnet) { vpc.subnets.select { |subnet| subnet.cidr_block == "10.10.0.0/24" }.first }
    let(:cf_subnet) { vpc.subnets.select { |subnet| subnet.cidr_block == "10.10.1.0/24" }.first }
    let(:cf_subnet_2) { vpc.subnets.select { |subnet| subnet.cidr_block == "10.10.2.0/24" }.first }

    before(:all) { run_bosh "aws create vpc #{aws_configuration_template}" }

    after(:all) { run_bosh "aws destroy #{aws_configuration_template}" }

    it "builds the VPC" do
      vpc.should_not be_nil
    end

    it "builds the VPC subnets" do
      bosh_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      bosh_subnet.instances.first.tags["Name"].should == "cf_nat_box"

      cf_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      cf_subnet.instances.count.should == 0

      cf_subnet_2.availability_zone.name.should == ENV["BOSH_VPC_SECONDARY_AZ"]
      cf_subnet_2.instances.count.should == 0
    end

    it "associates route tables with subnets" do
      bosh_routes = bosh_subnet.route_table.routes
      bosh_default_route = bosh_routes.select { |route| route.destination_cidr_block == "0.0.0.0/0" }.first
      bosh_default_route.target.id.should match /igw/
      bosh_local_route = bosh_routes.select { |route| route.destination_cidr_block == "10.10.0.0/16" }.first
      bosh_local_route.target.id.should == "local"

      cf_routes = cf_subnet.route_table.routes
      cf_default_route = cf_routes.select { |route| route.destination_cidr_block == "0.0.0.0/0" }.first
      cf_default_route.target.should == ec2.instances.first
      cf_local_route = cf_routes.select { |route| route.destination_cidr_block == "10.10.0.0/16" }.first
      cf_local_route.target.id.should == "local"

      cf2_routes = cf_subnet_2.route_table.routes
      cf2_routes.any? { |route| route.destination_cidr_block == "0.0.0.0/0" }.should be_false
      cf2_local_route = cf2_routes.select { |route| route.destination_cidr_block == "10.10.0.0/16" }.first
      cf2_local_route.target.id.should == "local"
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

    pending "can create and destroy an RDS configuration"
  end

  describe "S3" do
    #before(:all) { run_bosh "aws create s3 #{aws_configuration_template}" }
    #after(:all) { run_bosh "aws destroy #{aws_configuration_template}" }

    pending "can create and destroy an S3 configuration"
  end

  describe "all resources" do
    pending "can create and destroy a configuration of VPC, RDS, Route53, and S3"
  end
end