require 'spec_helper'
require '20140422000000_add_tertiary_az_to_vpc'

describe AddTertiaryAzToVpc do
  include MigrationSpecHelper

  before do
    ENV["BOSH_VPC_TERTIARY_AZ"] = "us-east-1c"
  end

  before do
    subject.stub(:load_receipt).and_return(YAML.load_file(asset "test-output.yml"))
    Bosh::Aws::VPC.should_receive(:find).with(ec2, "vpc-13724979").and_return(vpc)
  end

  subject { described_class.new(config, '') }

  let(:vpc) { double("vpc") }
  let(:cf3_id) { "subnet-abc123" }
  let(:services3_id) { "subnet-abc456" }
  let(:bosh3_id) { "subnet-abc789" }

  it "adds missing subnets for a tertiary AZ" do
    subnets = {
      "bosh3" => { "availability_zone" => "us-east-1c", "cidr" => "10.10.128.0/24", "default_route" => "igw" },
      "cf3" => { "availability_zone" => "us-east-1c", "cidr" => "10.10.144.0/20", "default_route" => "cf_nat_box1" },
      "services3" => { "availability_zone" => "us-east-1c", "cidr" => "10.10.160.0/20", "default_route" => "cf_nat_box1" },
    }

    vpc.should_receive(:create_subnets).with(subnets)
    vpc.should_receive(:create_nat_instances).with(subnets)
    vpc.should_receive(:setup_subnet_routes).with(subnets)


    vpc.should_receive(:subnets).and_return(
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "services1" => "subnet-xxxxxxx3",
        "services2" => "subnet-xxxxxxx4",
        "bosh1" => "subnet-xxxxxxx5",
        "bosh2" => "subnet-xxxxxxx6",
      },
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => cf3_id,
        "services1" => "subnet-xxxxxxx3",
        "services2" => "subnet-xxxxxxx4",
        "services3" => services3_id,
        "bosh1" => "subnet-xxxxxxx5",
        "bosh2" => "subnet-xxxxxxx6",
        "bosh3" => bosh3_id,
      }
    )

    subject.should_receive(:save_receipt) { |filename, contents|
      filename.should == "aws_vpc_receipt"
      contents["vpc"]["id"].should == "vpc-13724979" # quickly check we didn't wipe anything out
      contents["vpc"]["subnets"].should == {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => cf3_id,
        "services1" => "subnet-xxxxxxx3",
        "services2" => "subnet-xxxxxxx4",
        "services3" => services3_id,
        "bosh1" => "subnet-xxxxxxx5",
        "bosh2" => "subnet-xxxxxxx6",
        "bosh3" => bosh3_id,
      }
    }

    subject.execute
  end

  it "does not create the new subnets if they already exist" do
    vpc.should_receive(:subnets).and_return(
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => "subnet-existing1", # already there
        "services1" => "subnet-xxxxxxx3",
        "services2" => "subnet-xxxxxxx4",
        "bosh1" => "subnet-xxxxxxx5",
        "bosh2" => "subnet-xxxxxxx6",
        "bosh3" => "subnet-existing2", # already there
      },
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => "subnet-existing1", # already there
        "services1" => "subnet-xxxxxxx3",
        "services2" => "subnet-xxxxxxx4",
        "services3" => services3_id,
        "bosh1" => "subnet-xxxxxxx5",
        "bosh2" => "subnet-xxxxxxx6",
        "bosh3" => "subnet-existing2", # already there
      }
    )

    missing_subnets = {
      "services3" => {
        "availability_zone" => "us-east-1c",
        "cidr" => "10.10.160.0/20",
        "default_route" => "cf_nat_box1",
      },
    }

    vpc.should_receive(:create_subnets).with(missing_subnets)
    vpc.should_receive(:create_nat_instances).with(missing_subnets)
    vpc.should_receive(:setup_subnet_routes).with(missing_subnets)

    subject.should_receive(:save_receipt) { |filename, contents|
      filename.should == "aws_vpc_receipt"
      contents["vpc"]["id"].should == "vpc-13724979" # quickly check we didn't wipe anything out
      contents["vpc"]["subnets"].should == {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => "subnet-xxxxxxx2",
        "cf3" => "subnet-existing1", # already there
        "services1" => "subnet-xxxxxxx3",
        "services2" => "subnet-xxxxxxx4",
        "services3" => services3_id,
        "bosh1" => "subnet-xxxxxxx5",
        "bosh2" => "subnet-xxxxxxx6",
        "bosh3" => "subnet-existing2", # already there
      }
    }

    subject.execute
  end
end
