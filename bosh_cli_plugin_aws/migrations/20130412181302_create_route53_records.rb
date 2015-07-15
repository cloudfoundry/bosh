class CreateRoute53Records < Bosh::AwsCliPlugin::Migration
  def execute
    receipt = {}
    elastic_ip_specs = config["elastic_ips"]

    if elastic_ip_specs
      receipt["elastic_ips"] = {}
    else
      return
    end

    count = elastic_ip_specs.map{|_, spec| spec["instances"]}.inject(:+)
    say "allocating #{count} elastic IP(s)"
    ec2.allocate_elastic_ips(count)

    elastic_ips = ec2.elastic_ips

    elastic_ip_specs.each do |name, job|
      receipt["elastic_ips"][name] = {"ips" => elastic_ips.shift(job["instances"])}
    end

    elastic_ip_specs.each do |name, job|
      if job["dns_record"]
        say "adding A record for #{job["dns_record"]}.#{config["vpc"]["domain"]}"
        route53.add_record(
            job["dns_record"],
            config["vpc"]["domain"],
            receipt["elastic_ips"][name]["ips"],
            {ttl: job["ttl"]}
        ) # shouldn't have to get domain from config["vpc"]["domain"]; should use config["name"]
        receipt["elastic_ips"][name]["dns_record"] = job["dns_record"]
      end
    end
  ensure
    save_receipt("aws_route53_receipt", receipt)
  end
end
