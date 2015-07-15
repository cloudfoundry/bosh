require 'spec_helper'
require '20130827000001_add_secondary_az_to_vpc'

describe AddSecondaryAzToVpc do
  include MigrationSpecHelper

  subject { described_class.new(config, '') }

  before do
    allow(subject).to receive(:load_receipt).and_return(YAML.load_file(asset "test-output.yml"))
    expect(Bosh::AwsCliPlugin::VPC).to receive(:find).with(ec2, "vpc-13724979").and_return(vpc)
  end

  let(:vpc) { double("vpc") }
  let(:cf2_id) {"subnet-abc123"}
  let(:services2_id) {"subnet-abc456"}
  let(:bosh2_id) {"subnet-abc789"}

  it "adds missing subnets for a secondary AZ" do
    subnets = {
      "bosh2" => { "availability_zone" => "us-east-1b", "cidr" => "10.10.64.0/24", "default_route" => "igw" },
      "cf2" => { "availability_zone" => "us-east-1b", "cidr" => "10.10.80.0/20", "default_route" => "cf_nat_box1" },
      "services2" => { "availability_zone" => "us-east-1b", "cidr" => "10.10.96.0/20", "default_route" => "cf_nat_box1" },
    }

    expect(vpc).to receive(:create_subnets).with(subnets)
    expect(vpc).to receive(:create_nat_instances).with(subnets)
    expect(vpc).to receive(:setup_subnet_routes).with(subnets)


    expect(vpc).to receive(:subnets).and_return(
      {
        "cf1" => "subnet-xxxxxxx1",
      },
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => cf2_id,
        "services2" => services2_id,
        "bosh2" => bosh2_id,
      }
    )

    expect(subject).to receive(:save_receipt) { |filename, contents|
      expect(filename).to eq("aws_vpc_receipt")
      expect(contents["vpc"]["id"]).to eq("vpc-13724979") # quickly check we didn't wipe anything out
      expect(contents["vpc"]["subnets"]["cf1"]).to eq("subnet-xxxxxxx1") # quickly check other subnets are there
      expect(contents["vpc"]["subnets"]["cf2"]).to eq(cf2_id)
      expect(contents["vpc"]["subnets"]["services2"]).to eq(services2_id)
      expect(contents["vpc"]["subnets"]["bosh2"]).to eq(bosh2_id)
    }

    subject.execute
  end

  it "does not create the new subnets if they already exist" do
    expect(vpc).to receive(:subnets).and_return(
      {
        "cf1" => "subnet-xxxxxxx1",
        "cf2" => cf2_id,  # already there, panic!
        "bosh2" => bosh2_id,  # already there, panic!
      },
      {
      "cf1" => "subnet-xxxxxxx1",
      "cf2" => cf2_id,
      "services2" => services2_id,
      "bosh2" => bosh2_id
      }
    )

    missing_subnets = { "services2" => { "availability_zone" => "us-east-1b", "cidr" => "10.10.96.0/20", "default_route" => "cf_nat_box1" }, }

    expect(vpc).to receive(:create_subnets).with(missing_subnets)
    expect(vpc).to receive(:create_nat_instances).with(missing_subnets)
    expect(vpc).to receive(:setup_subnet_routes).with(missing_subnets)

    expect(subject).to receive(:save_receipt) { |filename, contents|
      expect(filename).to eq("aws_vpc_receipt")
      expect(contents["vpc"]["id"]).to eq("vpc-13724979") # quickly check we didn't wipe anything out
      expect(contents["vpc"]["subnets"]["cf1"]).to eq("subnet-xxxxxxx1") # quickly check other subnets are there
      expect(contents["vpc"]["subnets"]["cf2"]).to eq(cf2_id)
      expect(contents["vpc"]["subnets"]["services2"]).to eq(services2_id)
      expect(contents["vpc"]["subnets"]["bosh2"]).to eq(bosh2_id)
    }

    subject.execute
  end

end
