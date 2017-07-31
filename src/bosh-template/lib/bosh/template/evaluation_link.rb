require 'bosh/template/property_helper'

module Bosh
  module Template
    class EvaluationLink
      include PropertyHelper

      attr_reader :instances
      attr_reader :properties

      def initialize(instances, properties, instance_group, default_network, deployment, root_domain, dns_encoder)
        @instances = instances
        @properties = properties
        @instance_group = instance_group
        @default_network = default_network
        @deployment = deployment
        @root_domain = root_domain
        @dns_encoder = dns_encoder
      end

      def p(*args)
        names = Array(args[0])

        names.each do |name|
          result = lookup_property(@properties, name)
          return result unless result.nil?
        end

        return args[1] if args.length == 2
        raise UnknownProperty.new(names)
      end

      def if_p(*names)
        values = names.map do |name|
          value = lookup_property(@properties, name)
          return Bosh::Template::EvaluationContext::ActiveElseBlock.new(self) if value.nil?
          value
        end

        yield *values
        Bosh::Template::EvaluationContext::InactiveElseBlock.new
      end

      def address(criteria = {})
        raise NotImplementedError.new('link.address requires bosh director') if @dns_encoder.nil?

        full_criteria = criteria.merge(
          instance_group: @instance_group,
          default_network: @default_network,
          deployment: @deployment,
          root_domain: @root_domain,
        )

        @dns_encoder.encode_query(full_criteria)
      end
    end
  end
end
