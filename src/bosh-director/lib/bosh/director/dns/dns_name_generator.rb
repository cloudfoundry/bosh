module Bosh::Director
  class DnsNameGenerator
    def self.dns_record_name(hostname, job_name, network_name, deployment_name)
      dns_domain_name = Config.canonized_dns_domain_name
      network_name = Canonicalizer.canonicalize(network_name) unless network_name == '%'

      [ hostname,
        Canonicalizer.canonicalize(job_name),
        network_name,
        Canonicalizer.canonicalize(deployment_name),
        dns_domain_name
      ].join('.')
    end
  end
end