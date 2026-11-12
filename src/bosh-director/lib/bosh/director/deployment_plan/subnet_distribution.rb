require 'bosh/director/deployment_plan/subnet_distribution/first_fit'
require 'bosh/director/deployment_plan/subnet_distribution/least_loaded'

module Bosh
  module Director
    module DeploymentPlan
      # Selects how auto-allocated (dynamic) IPs on a manual network are distributed
      # across the subnets of an AZ. Chosen by the director-wide
      # `dynamic_subnet_strategy` config value.
      module SubnetDistribution
        FIRST_FIT    = 'first_fit'.freeze
        LEAST_LOADED = 'least_loaded'.freeze
        DEFAULT      = FIRST_FIT
        ALLOWED      = [FIRST_FIT, LEAST_LOADED].freeze

        # Builds the strategy for `name` (the director-wide dynamic_subnet_strategy value).
        # This is the single place that enforces the allowed set: nil/absent selects the
        # default, but any other unknown value fails loud with ValidationInvalidValue rather
        # than silently falling back, so a misconfigured director surfaces a clear error on
        # its first deployment.
        def self.build(name, networks:)
          case name
          when nil, FIRST_FIT
            FirstFit.new
          when LEAST_LOADED
            LeastLoaded.new(networks)
          else
            raise ValidationInvalidValue,
                  "Invalid dynamic_subnet_strategy '#{name}', valid values are: #{ALLOWED.join(', ')}"
          end
        end
      end
    end
  end
end
