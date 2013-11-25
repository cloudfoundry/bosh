require "spec_helper"
require "cli"
require "bosh_cli_plugin_aws"

describe 'bosh_cli_plugin_aws_external' do
  include Bosh::Spec::CommandHelper

  def ec2
    @ec2 ||= AWS::EC2.new
  end

  def s3
    @s3 ||= AWS::S3.new
  end

  def aws_configuration_template
    File.join(File.dirname(__FILE__), '..', '..', 'bosh_cli_plugin_aws', 'templates', 'aws_configuration_template.yml.erb')
  end

  before(:all) do
    AWS.config(
        {
            :access_key_id => ENV["BOSH_AWS_ACCESS_KEY_ID"],
            :secret_access_key => ENV["BOSH_AWS_SECRET_ACCESS_KEY"],
            :ec2_endpoint => "ec2.us-east-1.amazonaws.com",
            :max_retries => 2
        }
    )
    FileUtils.mkdir_p(BOSH_WORK_DIR)
    run_bosh "aws destroy"
    Bosh::Common.retryable(tries: 15) do
      ec2.vpcs.count == 0 &&
          ec2.key_pairs.map(&:name).empty? &&
          s3.buckets.to_a.empty?
    end

    # creating key pairs here because VPC creation involves creating a NAT instance
    # and instance creation requires an existing key pair.
    run_bosh "aws create key_pairs #{aws_configuration_template}"
    run_bosh "aws create vpc #{aws_configuration_template}"
  end

  after(:all) do
    ec2.key_pairs.map(&:name).should == ['bosh']
    run_bosh "aws destroy"
    Bosh::Common.retryable(tries: 15) do
      ec2.vpcs.count == 0 &&
          ec2.key_pairs.map(&:name).empty? &&
          s3.buckets.to_a.empty?
    end
  end

  describe "VPC" do
    let(:vpc) { ec2.vpcs.first }
    let(:elb) { AWS::ELB.new }
    let(:route53) { AWS::Route53.new }
    let(:bosh1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.0.0/24" } }
    let(:bosh_rds1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.1.0/24" } }
    let(:bosh_rds2_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.65.0/24" } }
    let(:cf1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.16.0/20" } }
    let(:services1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.32.0/20" } }
    let(:cf_elb1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.2.0/24" } }
    let(:cf_elb2_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.66.0/24" } }
    let(:cf_rds1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.3.0/24" } }
    let(:cf_rds2_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.67.0/24" } }
    let(:services_rds1_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.8.0/21" } }
    let(:services_rds2_subnet) { vpc.subnets.detect { |subnet| subnet.cidr_block == "10.10.72.0/21" } }

    it "builds the VPC" do
      vpc.should_not be_nil
    end

    it "builds the VPC subnets" do
      bosh1_subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
      bosh1_subnet.instances.first.tags["Name"].should == "cf_nat_box1"

      [cf1_subnet, services1_subnet].each do |subnet|
        subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
        subnet.instances.count.should == 0

        subnet.route_table.routes.any? do |route|
          route.instance && route.instance.private_ip_address == "10.10.0.10"
        end.should be(true)
      end

      [bosh_rds1_subnet, cf_rds1_subnet, cf_elb1_subnet, services_rds1_subnet].each do |subnet|
        subnet.availability_zone.name.should == ENV["BOSH_VPC_PRIMARY_AZ"]
        subnet.instances.count.should == 0
      end

      [bosh_rds2_subnet, cf_rds2_subnet, cf_elb2_subnet, services_rds2_subnet].each do |subnet|
        subnet.availability_zone.name.should == ENV["BOSH_VPC_SECONDARY_AZ"]
        subnet.instances.count.should == 0
      end
    end

    it "associates route tables with subnets" do
      bosh_routes = bosh1_subnet.route_table.routes
      bosh_default_route = bosh_routes.detect { |route| route.destination_cidr_block == "0.0.0.0/0" }
      bosh_default_route.target.id.should match(/igw/)
      bosh_local_route = bosh_routes.detect { |route| route.destination_cidr_block == "10.10.0.0/16" }
      bosh_local_route.target.id.should == "local"

      [cf1_subnet, services1_subnet].each do |subnet|
        routes = subnet.route_table.routes
        default_route = routes.detect { |route| route.destination_cidr_block == "0.0.0.0/0" }
        default_route.target.should == bosh1_subnet.instances.first
        local_route = routes.detect { |route| route.destination_cidr_block == "10.10.0.0/16" }
        local_route.target.id.should == "local"
      end
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
      load_balancer.subnets.sort {|s1, s2| s1.id <=> s2.id }.should == [cf_elb1_subnet, cf_elb2_subnet].sort {|s1, s2| s1.id <=> s2.id }
      load_balancer.security_groups.map(&:name).should == ["web"]

      config = Bosh::Aws::AwsConfig.new(aws_configuration_template)
      hosted_zone = route53.hosted_zones.detect { |zone| zone.name == "#{config.vpc_generated_domain}." }
      record_set = hosted_zone.resource_record_sets["\\052.#{config.vpc_generated_domain}.", 'CNAME'] # E.g. "*.midway.cf-app.com."
      record_set.should_not be_nil
      record_set.resource_records.first[:value] == load_balancer.dns_name
      record_set.ttl.should == 60
    end
  end

  describe "Route53" do
    let(:route53) { AWS::Route53.new }
    let(:hosted_zone) do
      route53.hosted_zones.detect { |hosted_zone| hosted_zone.name == "#{ENV["BOSH_VPC_SUBDOMAIN"]}.cf-app.com." }
    end
    let(:resource_record_sets) { hosted_zone.resource_record_sets }

    it "creates A records, allocates IPs, and deletes A records" do
      resource_record_sets.count { |record_set| record_set.type == "A" }.should == 0
      run_bosh "aws create route53 records #{aws_configuration_template}"
      a_records = resource_record_sets.select { |record_set| record_set.type == "A" }
      a_records.map { |record| record.name.split(".")[0] }.should =~ ["bosh", "bat", "micro"]
      a_records.map(&:ttl).uniq.should == [60]
      a_records.each do |record|
        record.resource_records.first[:value].should =~ /\d+\.\d+\.\d+\.\d+/ # should be an IP address
      end
    end

  end
end
