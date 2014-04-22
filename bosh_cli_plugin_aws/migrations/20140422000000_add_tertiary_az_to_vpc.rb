class AddTertiaryAzToVpc < Bosh::Aws::Migration
  include Bosh::Aws::MigrationHelper

  def execute
    vpc_receipt = load_receipt("aws_vpc_receipt")

    vpc = Bosh::Aws::VPC.find(ec2, vpc_receipt["vpc"]["id"])

    new_az = ENV["BOSH_VPC_TERTIARY_AZ"] || raise("must define $BOSH_VPC_TERTIARY_AZ")

    subnets = {
      "bosh3" => {"availability_zone" => new_az, "cidr" => "10.10.128.0/24", "default_route" => "igw"},
      "cf3" => {"availability_zone" => new_az, "cidr" => "10.10.144.0/20", "default_route" => "cf_nat_box1"},
      "services3" => {"availability_zone" => new_az, "cidr" => "10.10.160.0/20", "default_route" => "cf_nat_box1"},
    }

    existing_subnets = vpc.subnets

    subnets.reject! { |subnet, _|
      existing_subnets.include?(subnet).tap do |should_skip|
        say "  Skipping already-present subnet #{subnet.inspect}" if should_skip
      end
    }

    vpc.create_subnets(subnets) { |msg| say "  #{msg}" }
    vpc.create_nat_instances(subnets)
    vpc.setup_subnet_routes(subnets) { |msg| say "  #{msg}" }

    vpc_receipt["vpc"]["subnets"] = vpc.subnets
  ensure
    save_receipt("aws_vpc_receipt", vpc_receipt)
  end
end
