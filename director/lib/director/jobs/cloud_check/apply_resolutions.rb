# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    module CloudCheck
      class ApplyResolutions < BaseJob
        @queue = :normal

        # @param [String] deployment_name Deployment name
        # @param [Hash] resolutions Problem resolutions
        def initialize(deployment_name, resolutions)
          super

          @deployment_manager = Api::DeploymentManager.new
          @deployment = @deployment_manager.find_by_name(deployment_name)

          @resolved_count = 0
          unless resolutions.kind_of?(Hash)
            raise CloudcheckInvalidResolutionFormat,
                  "Invalid format for resolutions, " +
                  "Hash expected, #{resolutions.class} is given"
          end

          # Normalizing problem ids
          @resolutions =
            resolutions.inject({}) do |hash, (problem_id, solution_name)|
              hash[problem_id.to_s] = solution_name
              hash
            end
        end

        def perform
          with_deployment_lock do
            apply_resolutions
            "#{@resolved_count} resolved"
          end
        end

        def apply_resolutions
          problems = Models::DeploymentProblem.
            filter(:deployment_id => @deployment.id, :state => "open").all
          problem_ids = Set.new

          problems.each do |problem|
            problem_ids << problem.id.to_s
            unless @resolutions.has_key?(problem.id.to_s)
              raise CloudcheckResolutionNotProvided,
                    "Resolution for problem #{problem.id} (#{problem.type}) " +
                    "is not provided"
            end
          end

          # We might have some resolutions for problems that are no longer open
          # or just some bogus problem ids, in that case we still need to mention
          # them in event log so end user understands what actually happened.
          missing_problem_ids = @resolutions.keys.to_set - problem_ids

          begin_stage("Applying problem resolutions",
                      problems.size + missing_problem_ids.size)
          problems.each do |problem|
            apply_resolution(problem)
          end

          missing_problem_ids.each do |problem_id|
            if problem_id !~ /^\d+$/
              reason = "malformed id"
            else
              problem = Models::DeploymentProblem[problem_id.to_i]
              if problem.nil?
                reason = "not found"
              elsif problem.state != "open"
                reason = "state is '#{problem.state}'"
              elsif problem.deployment_id != @deployment.id
                reason = "not a part of this deployment"
              else
                reason = "reason unknown"
              end
            end

            track_and_log("Ignoring problem #{problem_id} (#{reason})") { }
          end
        end

        def apply_resolution(problem)
          # TODO: add audit
          handler = ProblemHandlers::Base.create_from_model(problem)
          handler.job = self

          resolution = @resolutions[problem.id.to_s] || handler.auto_resolution
          problem_summary = "#{problem.type} #{problem.resource_id}"
          resolution_summary = handler.resolution_plan(resolution)
          resolution_summary ||= "no resolution"

          begin
            track_and_log("#{problem_summary}: #{resolution_summary}") do
              handler.apply_resolution(resolution)
            end
          rescue Bosh::Director::ProblemHandlerError => e
            log_resolution_error(problem, e)
          end

          problem.state = "resolved" # TODO: add 'ignored' state?
          problem.save
          @resolved_count += 1

        rescue => e
          # TODO: need to understand if something here is potentially fatal
          # and deserves re-raising
          log_resolution_error(problem, e)
        end

        private

        def log_resolution_error(problem, error)
          logger.error("Error resolving problem `#{problem.id}': #{error}")
          logger.error(error.backtrace.join("\n"))
        end

        def with_deployment_lock
          Lock.new("lock:deployment:#{@deployment.name}").lock do
            yield
          end
        end
      end
    end
  end
end
