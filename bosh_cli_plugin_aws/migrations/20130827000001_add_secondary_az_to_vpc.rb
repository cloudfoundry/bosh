class AddSecondaryAzToVpc < Bosh::AwsCliPlugin::Migration
  include Bosh::AwsCliPlugin::MigrationHelper

  def execute
    vpc_receipt = load_receipt("aws_vpc_receipt")

    vpc = Bosh::AwsCliPlugin::VPC.find(ec2, vpc_receipt["vpc"]["id"])

    new_az = vpc_receipt["original_configuration"]["vpc"]["subnets"]["cf_elb2"]["availability_zone"]

    subnets = {
      "bosh2" => {"availability_zone" => new_az, "cidr" => "10.10.64.0/24", "default_route" => "igw"},
      "cf2" => {"availability_zone" => new_az, "cidr" => "10.10.80.0/20", "default_route" => "cf_nat_box1"},
      "services2" => {"availability_zone" => new_az, "cidr" => "10.10.96.0/20", "default_route" => "cf_nat_box1"},
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
