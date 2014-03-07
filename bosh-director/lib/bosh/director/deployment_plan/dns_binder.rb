module Bosh::Director
  class DeploymentPlan::DnsBinder
    include DnsHelper

    def initialize(deployment)
      @deployment = deployment
      @config = Config
    end

    def bind_deployment
      return unless @config.dns_enabled?

      domain = Models::Dns::Domain.find_or_create(
        :name => dns_domain_name,
        :type => 'NATIVE',
      )
      @deployment.dns_domain = domain

      soa_record = Models::Dns::Record.find_or_create(
        :domain_id => domain.id,
        :name => dns_domain_name,
        :type => 'SOA',
      )
      soa_record.content = SOA
      soa_record.ttl = 300
      soa_record.save

      # add NS record
      Models::Dns::Record.find_or_create(
        :domain_id => domain.id,
        :name => dns_domain_name,
        :type =>'NS', :ttl => TTL_4H,
        :content => dns_ns_record,
      )

      # add A record for name server
      Models::Dns::Record.find_or_create(
        :domain_id => domain.id,
        :name => dns_ns_record,
        :type =>'A', :ttl => TTL_4H,
        :content => @config.dns['address'],
      )
    end
  end
end
