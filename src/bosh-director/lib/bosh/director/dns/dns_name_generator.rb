module Bosh::Director
  class DnsNameGenerator
    def self.dns_record_name(hostname, job_name, network_name, deployment_name)
      dns_domain_name = Config.canonized_dns_domain_name

      if network_name == '%'
        canonicalized_network_name = '%'
      else
        canonicalized_network_name = Canonicalizer.canonicalize(network_name)
      end

      [ hostname,
        Canonicalizer.canonicalize(job_name),
        canonicalized_network_name,
        Canonicalizer.canonicalize(deployment_name),
        dns_domain_name
      ].join('.')
    end
  end
end