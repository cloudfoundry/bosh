require 'spec_helper'
require '20140422000001_create_diego_subnets'

describe CreateDiegoSubnets do
  include MigrationSpecHelper

  before do
    ENV["BOSH_VPC_PRIMARY_AZ"] = "us-east-1a"
    ENV["BOSH_VPC_SECONDARY_AZ"] = "us-east-1b"
    ENV["BOSH_VPC_TERTIARY_AZ"] = "us-east-1c"
  end

  before do
    subject.stub(:load_receipt).and_return(YAML.load_file(asset "test-output.yml"))
    Bosh::Aws::VPC.should_receive(:find).with(ec2, "vpc-13724979").and_return(vpc)
  end

  subject { described_class.new(config, '') }

  let(:vpc) { double("vpc") }

  let(:diego1_id) { "subnet-abc123" }
  let(:diego2_id) { "subnet-abc456" }
  let(:diego3_id) { "subnet-abc789" }

  it "adds a diego subnet to each AZ" do
    subnets = {
      "diego1" => { "availability_zone" => "us-east-1a", "cidr" => "10.10.50.0/25", "default_route" => "cf_nat_box1" },
      "diego2" => { "availability_zone" => "us-east-1b", "cidr" => "10.10.114.0/25", "default_route" => "cf_nat_box1" },
      "diego3" => { "availability_zone" => "us-east-1c", "cidr" => "10.10.178.0/25", "default_route" => "cf_nat_box1" },
    }

    vpc.should_receive(:create_subnets).with(subnets)
    vpc.should_receive(:create_nat_instances).with(subnets)
    vpc.should_receive(:setup_subnet_routes).with(subnets)

    vpc.should_receive(:subnets).and_return(
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => "subnet-xxxxxxx3",
        "services1" => "subnet-xxxxxxx4",
        "services2" => "subnet-xxxxxxx5",
        "services3" => "subnet-xxxxxxx6",
        "bosh1" => "subnet-xxxxxxx7",
        "bosh2" => "subnet-xxxxxxx8",
        "bosh3" => "subnet-xxxxxxx9",
        "diego1" => diego1_id,
        "diego2" => diego2_id,
        "diego3" => diego3_id,
      }
    )

    subject.should_receive(:save_receipt) { |filename, contents|
      filename.should == "aws_vpc_receipt"
      contents["vpc"]["id"].should == "vpc-13724979" # quickly check we didn't wipe anything out
      contents["vpc"]["subnets"].should == {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => "subnet-xxxxxxx3",
        "services1" => "subnet-xxxxxxx4",
        "services2" => "subnet-xxxxxxx5",
        "services3" => "subnet-xxxxxxx6",
        "bosh1" => "subnet-xxxxxxx7",
        "bosh2" => "subnet-xxxxxxx8",
        "bosh3" => "subnet-xxxxxxx9",
        "diego1" => diego1_id,
        "diego2" => diego2_id,
        "diego3" => diego3_id,
      }
    }

    subject.execute
  end
end
