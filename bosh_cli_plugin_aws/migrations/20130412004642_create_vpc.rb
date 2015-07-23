class CreateVpc < Bosh::AwsCliPlugin::Migration
  def execute
    receipt = {}

    receipt["aws"] = config["aws"]

    vpc = Bosh::AwsCliPlugin::VPC.create(ec2, config["vpc"]["cidr"], config["vpc"]["instance_tenancy"])
    receipt["vpc"] = {"id" => vpc.vpc_id, "domain" => config["vpc"]["domain"]}

    receipt["original_configuration"] = config

    unless was_vpc_eventually_available?(vpc)
      err "VPC #{vpc.vpc_id} was not available within 60 seconds, giving up"
    end

    say "creating internet gateway"
    igw = ec2.create_internet_gateway
    vpc.attach_internet_gateway(igw.id)

    security_groups = config["vpc"]["security_groups"]
    say "creating security groups: #{security_groups.map { |group| group["name"] }.join(", ")}"
    vpc.create_security_groups(security_groups)

    subnets = config["vpc"]["subnets"]
    say "creating subnets: #{subnets.keys.join(", ")}"
    vpc.create_subnets(subnets) { |msg| say "  #{msg}" }
    vpc.create_nat_instances(subnets)
    vpc.setup_subnet_routes(subnets) { |msg| say "  #{msg}" }
    receipt["vpc"]["subnets"] = vpc.subnets

    elbs = config["vpc"]["elbs"]
    ssl_certs = config["ssl_certs"]

    say "creating load balancers: #{elbs.keys.join(", ")}" if elbs
    elbs.each do |name, settings|
      settings["domain"] = config["vpc"]["domain"]
      e = elb.create(name, vpc, settings, ssl_certs)
      if settings["dns_record"]
        say "adding CNAME record for #{settings["dns_record"]}.#{config["vpc"]["domain"]}"
        route53.add_record(settings["dns_record"], config["vpc"]["domain"], [e.dns_name], {ttl: settings["ttl"], type: 'CNAME'})
      end
    end

    dhcp_options = config["vpc"]["dhcp_options"]
    say "creating DHCP options"
    vpc.create_dhcp_options(dhcp_options)
  rescue Bosh::AwsCliPlugin::ELB::BadCertificateError => e
    err e.message
  ensure
    save_receipt("aws_vpc_receipt", receipt)
  end

  private

  def was_vpc_eventually_available?(vpc)
    (1..60).any? do |attempt|
      begin
        sleep 1 unless attempt == 1
        vpc.state.to_s == "available"
      rescue Exception => e
        say("Waiting for vpc, continuing after #{e.class}: #{e.message}")
      end
    end
  end
end
