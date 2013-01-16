require "spec_helper"
require "tmpdir"

describe Bosh::Cli::Command::AWS do
  def mock_ec2
    ec2 = double("ec2")
    yield ec2 if block_given?
    AWS::EC2.should_receive(:new).and_return(ec2)
  end

  let(:aws) { Bosh::Cli::Command::AWS.new }

  it "should create a vpc" do
    mock_ec2 do |ec2|
      vpcs = double("vpcs")
      vpcs.should_receive(:create).with("1.0.0.0/16", {}).and_return(double("vpc", :id => "vpc-xxxxxxxx"))
      ec2.stub(:vpcs => vpcs)
    end

    aws.should_receive(:flush_output_state).and_return
    aws.setup_ec2({})
    aws.create_vpc({"cidr" => "1.0.0.0/16"})
    aws.output_state["vpc"]["id"].should == "vpc-xxxxxxxx"
  end

  describe "elastic IPs" do
    it "should allocate elastic IPs" do
      mock_ec2 do |ec2|
        eip = double("elastic_ip", :public_ip => "1.2.3.4")
        elastic_ips = double("elastic_ips")
        elastic_ips.should_receive(:allocate).with(:vpc => true).exactly(5).times.and_return(eip)
        ec2.stub(:elastic_ips => elastic_ips)
      end

      aws.setup_ec2({})
      aws.should_receive(:flush_output_state)
      aws.allocate_elastic_ips(5)
      aws.output_state.should have_key("elastic_ips")
      aws.output_state["elastic_ips"].size.should == 5
      aws.output_state["elastic_ips"].first.should == "1.2.3.4"
    end
  end

  describe "subnets" do
    it "should be created without az if az is absent" do
      subnets = double("subnets")
      subnets.should_receive(:create).with("1.0.10.0/24", {})

      mock_ec2

      aws.setup_ec2({})
      aws.stub(:vpc).and_return(double("vpc", :id => "vpc-xxxxxxxx", :subnets => subnets))
      aws.create_subnets([{"cidr" => "1.0.10.0/24"}])
    end

    it "should be created with az if az is present" do
      subnets = double("subnets")
      subnets.should_receive(:create).with("1.0.10.0/24", {:availability_zone => "us-east-1"})

      mock_ec2

      aws.setup_ec2({})
      aws.vpc = double("vpc", :id => "vpc-xxxxxxxx", :subnets => subnets)
      aws.create_subnets([{"cidr" => "1.0.10.0/24", "availability_zone" => "us-east-1"}])
    end
  end

  describe "dhcp_options" do
    it "should create dhcp_options" do
      mock_ec2 do |ec2|
        dhcp_option = double("dhcp")
        dhcp_option.should_receive(:associate).with("vpc-xxxxxxxx")
        dhcp_options = double("dhcp_options")
        dhcp_options.should_receive(:create).with({}).and_return(dhcp_option)
        ec2.stub(:dhcp_options => dhcp_options)
      end

      aws.setup_ec2({})
      aws.vpc = double("vpc", :id => "vpc-xxxxxxxx")
      aws.create_dhcp_options({})
    end
  end

  describe "security groups" do

    before do
      mock_ec2
    end

    let(:security_groups) { double("security_groups") }
    let(:security_group) { double("security_group") }

    def create_security_groups (ingress_rules)
      aws.setup_ec2({})
      aws.vpc = double("vpc", :id => "vpc-xxxxxxxx", :security_groups => security_groups)

      aws.create_security_groups [
          "name" => "sg",
          "ingress" => ingress_rules
      ]
    end

    it "should be created" do
      security_groups.stub(:each)

      security_group.should_receive(:authorize_ingress).with(:tcp, 22, "1.2.3.0/24")
      security_group.should_receive(:authorize_ingress).with(:tcp, 23, "1.2.4.0/24")
      security_groups.should_receive(:create).with("sg").and_return(security_group)

      create_security_groups [
        {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"},
        {"protocol" => :tcp, "ports" => 23, "sources" => "1.2.4.0/24"}
      ]
    end

    it "should delete unused existing security group on create" do
      security_group.stub(:delete)

      security_group.should_receive(:authorize_ingress).with(:tcp, 22, "1.2.3.0/24")
      security_group.should_receive(:name).and_return("sg")
      security_groups.should_receive(:each).and_yield(security_group)
      security_groups.should_receive(:create).with("sg").and_return(security_group)

      create_security_groups [
          {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"}
      ]
    end

    it "should not delete existing security group if in use" do
      security_group.should_receive(:name).and_return("sg")
      security_group.should_receive(:delete).and_raise(::AWS::EC2::Errors::DependencyViolation)
      security_groups.should_receive(:each).and_yield(security_group)
      security_groups.should_not_receive(:create)

      create_security_groups [
        {"protocol" => :tcp, "ports" => 22, "sources" => "1.2.3.0/24"}
      ]
    end
  end

  describe "output state" do

    before do
      @config_dir = Dir.mktmpdir
    end

    after do
      FileUtils.rm_rf(@config_dir)
    end

    it "should be flushable" do
      aws.setup_ec2(foo: :bar)
      aws.should_receive(:config_dir).and_return(@config_dir)

      aws.flush_output_state

      file = File.join(@config_dir, Bosh::Cli::Command::AWS::OUTPUT_FILE)
      output = YAML.load_file(file)
      output['aws'].should == {foo: :bar}
    end
  end
end
