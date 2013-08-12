require 'spec_helper'
require '20130412004642_create_vpc'

describe CreateVpc do
  include MigrationSpecHelper

  subject { described_class.new(config, nil, '')}

  def make_fake_vpc!(overrides = {})
    fake_vpc = double("vpc")
    fake_igw = double(AWS::EC2::InternetGateway, id: "id2")

    Bosh::Aws::VPC.stub(:create).and_return(fake_vpc)

    fake_vpc.stub(:vpc_id).and_return("vpc id")
    fake_vpc.stub(:create_dhcp_options)
    fake_vpc.stub(:create_security_groups)
    fake_vpc.stub(:create_subnets)
    fake_vpc.stub(:create_nat_instances)
    fake_vpc.stub(:setup_subnet_routes)
    fake_vpc.stub(:subnets).and_return({'bosh' => "amz-subnet1", 'name2' => "amz-subnet2"})
    fake_vpc.stub(:attach_internet_gateway)
    ec2.stub(:allocate_elastic_ips)
    ec2.stub(:force_add_key_pair)
    ec2.stub(:create_internet_gateway).and_return(fake_igw)
    ec2.stub(:elastic_ips).and_return(["1.2.3.4", "5.6.7.8"])
    elb.stub(:create).
      with("external-elb-1", fake_vpc, anything, hash_including('my_cert_1' => anything)).
      and_return(double("new elb", dns_name: 'elb-123.example.com'))
    route53.stub(:create_zone)
    route53.stub(:add_record)
    fake_vpc
  end

  it "should flush the output to a YAML file" do
    fake_vpc = make_fake_vpc!
    fake_vpc.stub(:state).and_return(:available)
    output_state = {}
    output_state["vpc"] = {
        "id" => "vpc id",
        "domain"=>"dev102.cf.com",
        "subnets" => {"bosh" => "amz-subnet1", "name2" => "amz-subnet2"}
    }
    output_state["original_configuration"] = config
    output_state["aws"] = config["aws"]

    subject.should_receive(:save_receipt) do |receipt_name, receipt|
      receipt_name.should == 'aws_vpc_receipt'
      receipt.should == output_state
    end

    subject.execute
  end

  context "when the VPC is not immediately available" do
    it "should try several times and continue when available" do
      fake_vpc = make_fake_vpc!
      fake_vpc.should_receive(:state).exactly(3).times.and_return(:pending, :pending, :available)
      subject.execute
    end

    it "should fail after 60 attempts when not available" do
      fake_vpc = make_fake_vpc!
      fake_vpc.stub(:state).and_return(:pending)
      expect {  subject.execute }.to raise_error
    end
  end
end
