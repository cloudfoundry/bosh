require "spec_helper"
require "cli"
require "bosh_aws_bootstrap"

describe 'bosh_aws_bootstrap_external' do
  include Bosh::Spec::CommandHelper

  before(:all) do
    AWS.config(
        {
            :access_key_id => ENV["BOSH_AWS_ACCESS_KEY_ID"],
            :secret_access_key => ENV["BOSH_AWS_SECRET_ACCESS_KEY"],
            :ec2_endpoint => "ec2.us-east-1.amazonaws.com",
            :max_retries => 2
        }
    )
  end

  let(:ec2) { AWS::EC2.new }
  let(:elb) { AWS::ELB.new }
  let(:route53) { AWS::Route53.new }

  let(:aws_configuration_template) { File.join(File.dirname(__FILE__), '..', '..', 'bosh_aws_bootstrap', 'templates', 'aws_configuration_template.yml.erb') }

  describe "VPC" do
    let(:vpc) { ec2.vpcs.first }
    let(:bosh_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.0.0/24" } }
    let(:cf_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.2.0/23" } }
    let(:services_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.4.0/23" } }
    let(:rds_subnet_1) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.1.0/28" } }
    let(:rds_subnet_2) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.1.16/28" } }

    before(:all) do
      ec2.vpcs.count.should == 0

      # creating key pairs here because VPC creation involves creating a NAT instance
      # and instance creation requires an existing key pair.
      run_bosh "aws create key_pairs #{aws_configuration_template}"
      run_bosh "aws create vpc #{aws_configuration_template}"
    end

    after(:all) do
      run_bosh "aws destroy"

      ec2.vpcs.count.should == 0
    end

    it "builds the VPC" do
      vpc.should_not be_nil
    end

    it "builds the VPC subnets" do
      bosh_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      bosh_subnet.instances.first.tags["Name"].should == "cf_nat_box"

      cf_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      cf_subnet.instances.count.should == 0

      cf_subnet.route_table.routes.any? do |route|
        route.instance && route.instance.private_ip_address == "10.10.0.10"
      end.should be_true

      services_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      services_subnet.instances.count.should == 0

      services_subnet.route_table.routes.any? do |route|
        route.instance && route.instance.private_ip_address == "10.10.0.10"
      end.should be_true

      rds_subnet_1.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      rds_subnet_1.instances.count.should == 0

      rds_subnet_2.availability_zone.name.should == ENV["BOSH_VPC_SECONDARY_AZ"]
      rds_subnet_2.instances.count.should == 0
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

      services_routes = services_subnet.route_table.routes
      services_default_route = services_routes.detect { |route| route.destination_cidr_block == "0.0.0.0/0" }
      services_default_route.target.should == bosh_subnet.instances.first

      services_local_route = services_routes.detect { |route| route.destination_cidr_block == "10.10.0.0/16" }
      services_local_route.target.id.should == "local"
    end

    it "assigns DHCP options" do
      vpc.dhcp_options.configuration[:domain_name_servers].should =~ ['10.10.0.6', '10.10.0.2']
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

    it "configures ELBs" do
      load_balancer = elb.load_balancers.detect { |lb| lb.name == "cfrouter" }
      load_balancer.should_not be_nil
      load_balancer.subnets.should == [bosh_subnet]
      load_balancer.security_groups.map(&:name).should == ["web"]

      hosted_zone = route53.hosted_zones.detect { |hosted_zone| hosted_zone.name == "#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com." }
      record_set = hosted_zone.resource_record_sets["\\052.#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com.", 'CNAME'] # E.g. "*.midway.cf-app.com."
      record_set.should_not be_nil
      record_set.resource_records.first[:value] == load_balancer.dns_name
      record_set.ttl.should == 60
    end
  end

  describe "key pairs" do
    before do
      ec2.key_pairs.map(&:name).should == []

      run_bosh "aws create key_pairs #{aws_configuration_template}"
    end

    it "creates and deletes key pairs" do
      ec2.key_pairs.map(&:name).should == [ENV["BOSH_KEY_PAIR_NAME"] || "bosh"]
    end

    after do
      run_bosh "aws destroy"

      ec2.key_pairs.map(&:name).should == []
    end
  end

  describe "S3" do
    let(:s3) { AWS::S3.new }

    before do
      s3.buckets.count.should == 0

      run_bosh "aws create s3 #{aws_configuration_template}"
    end

    it "creates s3 buckets and deletes them" do
      s3.buckets.map(&:name).should == ["#{ENV["BOSH_VPC_SUBDOMAIN"]}-bosh-blobstore"]
    end

    after do
      run_bosh "aws destroy"

      s3.buckets.count.should == 0
    end
  end

  describe "Route53" do
    let(:route53) { AWS::Route53.new }
    let(:hosted_zone) do
      route53.hosted_zones.detect { |hosted_zone| hosted_zone.name == "#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com." }
    end
    let(:resource_record_sets) { hosted_zone.resource_record_sets }

    before do
      resource_record_sets.count { |record_set| record_set.type == "A" }.should == 0

      run_bosh "aws create route53 records #{aws_configuration_template}"
    end

    it "creates A records, allocates IPs, and deletes A records" do
      a_records = resource_record_sets.select { |record_set| record_set.type == "A" }
      a_records.map { |record| record.name.split(".")[0] }.should =~ ["bosh", "bat", "micro"]
      a_records.map(&:ttl).uniq.should == [60]
      a_records.each do |record|
        record.resource_records.first[:value].should =~ /\d+\.\d+\.\d+\.\d+/ # should be an IP address
      end
    end

    after do
      run_bosh "aws destroy"

      resource_record_sets.count { |record_set| record_set.type == "A" }.should == 0
    end
  end
end
