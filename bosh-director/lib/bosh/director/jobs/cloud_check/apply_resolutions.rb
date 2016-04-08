# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    module CloudCheck
      class ApplyResolutions < BaseJob
        include LockHelper

        @queue = :normal

        def self.job_type
          :cck_apply
        end

        # @param [String] deployment_name Deployment name
        # @param [Hash] resolutions Problem resolutions
        def initialize(deployment_name, resolutions)
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

          @problem_resolver = ProblemResolver.new(@deployment)
        end

        def perform
          with_deployment_lock(@deployment) do
            count, error_message = @problem_resolver.apply_resolutions(@resolutions)

            if error_message
              raise Bosh::Director::ProblemHandlerError, error_message
            end

            "#{count} resolved"
          end
        end

      end
    end
  end
end
