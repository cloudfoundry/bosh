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
    let(:bosh_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.0.0/24" } }
    let(:cf_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.1.0/24" } }
    let(:cf_subnet_2) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.2.0/24" } }

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
      bosh_default_route = bosh_routes.detect { |route| route.destination_cidr_block == "0.0.0.0/0" }
      bosh_default_route.target.id.should match /igw/
      bosh_local_route = bosh_routes.detect { |route| route.destination_cidr_block == "10.10.0.0/16" }
      bosh_local_route.target.id.should == "local"

      cf_routes = cf_subnet.route_table.routes
      cf_default_route = cf_routes.detect { |route| route.destination_cidr_block == "0.0.0.0/0" }
      cf_default_route.target.should == bosh_subnet.instances.first
      cf_local_route = cf_routes.detect { |route| route.destination_cidr_block == "10.10.0.0/16" }
      cf_local_route.target.id.should == "local"

      cf2_routes = cf_subnet_2.route_table.routes
      cf2_routes.any? { |route| route.destination_cidr_block == "0.0.0.0/0" }.should be_false
      cf2_local_route = cf2_routes.detect { |route| route.destination_cidr_block == "10.10.0.0/16" }
      cf2_local_route.target.id.should == "local"
    end

    it "assigns DHCP options" do
      vpc.dhcp_options.configuration[:domain_name_servers].should =~ ['10.10.0.5', '10.10.0.2']
    end

    it "assigns security groups" do
      open = vpc.security_groups.detect { |sg| sg.name == "open" }

      tcp_permissions = open.ingress_ip_permissions.detect { |p| p.protocol == :tcp }
      tcp_permissions.should_not be_nil
      tcp_permissions.ip_ranges.should == ["0.0.0.0/0"]
      tcp_permissions.port_range.should == (0..65535)

      udp_permissions = open.ingress_ip_permissions.detect { |p| p.protocol == :udp }
      udp_permissions.should_not be_nil
      udp_permissions.ip_ranges.should == ["0.0.0.0/0"]
      udp_permissions.port_range.should == (0..65535)

      bosh = vpc.security_groups.detect { |sg| sg.name == "bosh" }

      tcp_permissions = bosh.ingress_ip_permissions.detect { |p| p.protocol == :tcp }
      tcp_permissions.should_not be_nil
      tcp_permissions.ip_ranges.should == ["0.0.0.0/0"]
      tcp_permissions.port_range.should == (0..65535)

      udp_permissions = bosh.ingress_ip_permissions.detect { |p| p.protocol == :udp }
      udp_permissions.should_not be_nil
      udp_permissions.ip_ranges.should == ["0.0.0.0/0"]
      udp_permissions.port_range.should == (0..65535)

      bat = vpc.security_groups.detect { |sg| sg.name == "bat" }

      ssh_permissions = bat.ingress_ip_permissions.detect { |p| p.port_range == (22..22) }
      ssh_permissions.should_not be_nil
      ssh_permissions.ip_ranges.should == ["0.0.0.0/0"]
      ssh_permissions.protocol.should == :tcp

      other_permissions = bat.ingress_ip_permissions.detect { |p| p.port_range == (4567..4567) }
      other_permissions.should_not be_nil
      other_permissions.ip_ranges.should == ["0.0.0.0/0"]
      other_permissions.protocol.should == :tcp

      cf = vpc.security_groups.detect { |sg| sg.name == "cf" }

      tcp_permissions = cf.ingress_ip_permissions.detect { |p| p.protocol == :tcp }
      tcp_permissions.should_not be_nil
      tcp_permissions.ip_ranges.should == ["0.0.0.0/0"]
      tcp_permissions.port_range.should == (0..65535)

      udp_permissions = cf.ingress_ip_permissions.detect { |p| p.protocol == :udp }
      udp_permissions.should_not be_nil
      udp_permissions.ip_ranges.should == ["0.0.0.0/0"]
      udp_permissions.port_range.should == (0..65535)

      web = vpc.security_groups.detect { |sg| sg.name == "web" }

      http_permissions = web.ingress_ip_permissions.detect { |p| p.port_range == (80..80) }
      http_permissions.should_not be_nil
      http_permissions.ip_ranges.should == ["0.0.0.0/0"]
      http_permissions.protocol.should == :tcp

      https_permissions = web.ingress_ip_permissions.detect { |p| p.port_range == (443..443) }
      https_permissions.should_not be_nil
      https_permissions.ip_ranges.should == ["0.0.0.0/0"]
      https_permissions.protocol.should == :tcp
    end

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
