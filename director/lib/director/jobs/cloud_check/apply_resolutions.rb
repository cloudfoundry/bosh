module Bosh::Director
  module Jobs
    module CloudCheck
      class ApplyResolutions < BaseJob
        @queue = :normal

        def initialize(deployment_name, resolutions)
          super

          @deployment = Models::Deployment.find(:name => deployment_name)
          raise "Deployment `#{deployment_name}' not found" if @deployment.nil?

          @resolved_count = 0
          unless resolutions.kind_of?(Hash)
            raise "Invalid format for resolutions, Hash expected, #{resolutions.class} is given"
          end

          # Normalizing problem ids
          @resolutions = resolutions.inject({}) do |h, (problem_id, solution_name)|
            h[problem_id.to_s] = solution_name
            h
          end
        end

        def perform
          with_deployment_lock do
            apply_resolutions
            "#{@resolved_count} resolved"
          end
        end

        def apply_resolutions
          problems = Models::DeploymentProblem.filter(:deployment_id => @deployment.id, :state => "open").all
          @unresolved_count = problems.count

          problems.each do |problem|
            if !@resolutions.has_key?(problem.id.to_s)
              raise "Resolution for problem #{problem.id} (#{problem.type}) is not provided"
            end
          end

          begin_stage("Applying problem resolutions", problems.size)
          problems.each do |problem|
            apply_resolution(problem)
          end
        end

        def apply_resolution(problem)
          # TODO: add audit
          handler = ProblemHandlers::Base.create_from_model(problem)
          handler.job = self

          resolution = @resolutions[problem.id.to_s] || handler.auto_resolution
          resolution_summary = "#{handler.description} [#{handler.resolution_plan(resolution) || "n/a"}]"

          track_and_log(resolution_summary) do
            if !handler.problem_still_exists? || handler.apply_resolution(resolution)
              problem.state = "resolved"
              problem.save
              @resolved_count += 1
            end
          end

        rescue Bosh::Director::ProblemHandlers::HandlerError => e
          @logger.error("Error resolving problem `#{problem.id}': #{e}")
          @logger.error(e.backtrace.join("\n"))
        end

        private

        def with_deployment_lock
          Lock.new("lock:deployment:#{@deployment.name}").lock do
            yield
          end
        end
      end
    end
  end
end
