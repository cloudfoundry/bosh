# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    module CloudCheck
      class ApplyResolutions < BaseJob
        include LockHelper

        @queue = :normal

        # @param [String] deployment_name Deployment name
        # @param [Hash] resolutions Problem resolutions
        def initialize(deployment_name, resolutions)
          super

          @deployment_manager = Api::DeploymentManager.new
          @deployment = @deployment_manager.find_by_name(deployment_name)

          unless resolutions.kind_of?(Hash)
            raise CloudcheckInvalidResolutionFormat,
                  "Invalid format for resolutions, Hash expected, #{resolutions.class} is given"
          end

          # Normalizing problem ids
          @resolutions =
            resolutions.inject({}) { |hash, (problem_id, solution_name)|
              hash[problem_id.to_s] = solution_name
              hash
            }

          @problem_resolver = ProblemResolver.new(deployment_name)
        end

        def perform
          with_deployment_lock(@deployment) do
            count = @problem_resolver.apply_resolutions(@resolutions)
            "#{count} resolved"
          end
        end

      end
    end
  end
end
