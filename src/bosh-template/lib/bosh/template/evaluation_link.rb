require 'bosh/template/property_helper'

module Bosh
  module Template
    class EvaluationLink
      include PropertyHelper

      attr_reader :instances
      attr_reader :properties

      def initialize(
        instances,
        properties,
        group_name,
        group_type,
        default_network,
        deployment_name,
        root_domain,
        dns_encoder,
        use_short_dns
      )
        @instances = instances
        @properties = properties
        @group_name = group_name
        @group_type = group_type
        @default_network = default_network
        @deployment_name = deployment_name
        @root_domain = root_domain
        @dns_encoder = dns_encoder
        @use_short_dns = use_short_dns
      end

      def p(*args)
        names = Array(args[0])

        names.each do |name|
          result = lookup_property(@properties, name)
          return result unless result.nil?
        end

        return args[1] if args.length == 2

        raise UnknownProperty, names
      end

      def if_p(*names)
        values = names.map do |name|
          value = lookup_property(@properties, name)
          return Bosh::Template::EvaluationContext::ActiveElseBlock.new(self) if value.nil?

          value
        end

        yield(*values)

        Bosh::Template::EvaluationContext::InactiveElseBlock.new
      end

      def address(criteria = {})
        raise NotImplementedError, 'link.address requires bosh director' if @dns_encoder.nil?

        full_criteria = criteria.merge(
          group_name: @group_name,
          group_type: @group_type,
          default_network: @default_network,
          deployment_name: @deployment_name,
          root_domain: @root_domain,
        )
        @dns_encoder.encode_query(full_criteria, @use_short_dns)
      end
    end
  end
end
