class CreateDiegoSubnets < Bosh::Aws::Migration
  include Bosh::Aws::MigrationHelper

  def execute
    vpc_receipt = load_receipt("aws_vpc_receipt")

    vpc = Bosh::Aws::VPC.find(ec2, vpc_receipt["vpc"]["id"])

    z1 = ENV["BOSH_VPC_PRIMARY_AZ"] || raise("must define $BOSH_VPC_PRIMARY_AZ")
    z2 = ENV["BOSH_VPC_SECONDARY_AZ"] || raise("must define $BOSH_VPC_SECONDARY_AZ")
    z3 = ENV["BOSH_VPC_TERTIARY_AZ"] || raise("must define $BOSH_VPC_TERTIARY_AZ")

    subnets = {
      "diego1" => { "availability_zone" => z1, "cidr" => "10.10.50.0/25", "default_route" => "cf_nat_box1" },
      "diego2" => { "availability_zone" => z2, "cidr" => "10.10.114.0/25", "default_route" => "cf_nat_box1" },
      "diego3" => { "availability_zone" => z3, "cidr" => "10.10.178.0/25", "default_route" => "cf_nat_box1" },
    }

    vpc.create_subnets(subnets) { |msg| say "  #{msg}" }
    vpc.create_nat_instances(subnets)
    vpc.setup_subnet_routes(subnets) { |msg| say "  #{msg}" }

    vpc_receipt["vpc"]["subnets"] = vpc.subnets
  ensure
    save_receipt("aws_vpc_receipt", vpc_receipt)
  end
end
