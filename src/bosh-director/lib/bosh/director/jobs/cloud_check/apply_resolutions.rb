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
        # @param [Hash] max_in_flight_overrides Instance Group max_in_flight overrides
        def initialize(deployment_name, resolutions, max_in_flight_overrides)
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

          # Normalizing max_in_flight
          @max_in_flight_overrides =
            max_in_flight_overrides.inject({}) { |hash, (instance_group, override)|
              hash[instance_group] = override.to_s
              hash
            }

          @problem_resolver = ProblemResolver.new(@deployment)
        end

        def perform
          with_deployment_lock(@deployment) do
            count, error_message = @problem_resolver.apply_resolutions(@resolutions, @max_in_flight_overrides)

            if error_message
              raise Bosh::Director::ProblemHandlerError, error_message
            end

            Bosh::Director::PostDeploymentScriptRunner.run_post_deploys_after_resurrection(@deployment)

            "#{count} resolved"
          end
        end

      end
    end
  end
end
