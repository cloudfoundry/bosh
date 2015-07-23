require 'spec_helper'
require '20130412004642_create_vpc'

describe CreateVpc do
  include MigrationSpecHelper

  subject { described_class.new(config, '')}

  def make_fake_vpc!(overrides = {})
    fake_vpc = double("vpc")
    fake_igw = double(AWS::EC2::InternetGateway, id: "id2")

    allow(Bosh::AwsCliPlugin::VPC).to receive(:create).and_return(fake_vpc)

    allow(fake_vpc).to receive(:vpc_id).and_return("vpc id")
    allow(fake_vpc).to receive(:create_dhcp_options)
    allow(fake_vpc).to receive(:create_security_groups)
    allow(fake_vpc).to receive(:create_subnets)
    allow(fake_vpc).to receive(:create_nat_instances)
    allow(fake_vpc).to receive(:setup_subnet_routes)
    allow(fake_vpc).to receive(:subnets).and_return({'bosh' => "amz-subnet1", 'name2' => "amz-subnet2"})
    allow(fake_vpc).to receive(:attach_internet_gateway)
    allow(ec2).to receive(:allocate_elastic_ips)
    allow(ec2).to receive(:force_add_key_pair)
    allow(ec2).to receive(:create_internet_gateway).and_return(fake_igw)
    allow(ec2).to receive(:elastic_ips).and_return(["1.2.3.4", "5.6.7.8"])
    allow(elb).to receive(:create).with("external-elb-1", fake_vpc, anything, hash_including('my_cert_1' => anything)).and_return(double("new elb", dns_name: 'elb-123.example.com'))
    allow(route53).to receive(:create_zone)
    allow(route53).to receive(:add_record)
    fake_vpc
  end

  it "should flush the output to a YAML file" do
    fake_vpc = make_fake_vpc!
    allow(fake_vpc).to receive(:state).and_return(:available)
    output_state = {}
    output_state["vpc"] = {
        "id" => "vpc id",
        "domain"=>"dev102.cf.com",
        "subnets" => {"bosh" => "amz-subnet1", "name2" => "amz-subnet2"}
    }
    output_state["original_configuration"] = config
    output_state["aws"] = config["aws"]

    expect(subject).to receive(:save_receipt) do |receipt_name, receipt|
      expect(receipt_name).to eq('aws_vpc_receipt')
      expect(receipt).to eq(output_state)
    end

    subject.execute

  end

  context "when the VPC is not immediately available" do
    it "should try several times and continue when available" do
      fake_vpc = make_fake_vpc!
      expect(fake_vpc).to receive(:state).exactly(3).times.and_return(:pending, :pending, :available)
      subject.execute
    end

    it "should fail after 60 attempts when not available" do
      fake_vpc = make_fake_vpc!
      allow(fake_vpc).to receive(:state).and_return(:pending)
      expect {  subject.execute }.to raise_error
    end
  end
end
