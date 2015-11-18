module Bosh::Director
  class ProblemResolver

    attr_reader :event_log, :logger

    def initialize(deployment)
      @deployment = deployment
      @resolved_count = 0

      #temp
      @event_log = Config.event_log
      @logger = Config.logger
    end

    def begin_stage(stage_name, n_steps)
      event_log.begin_stage(stage_name, n_steps)
      logger.info(stage_name)
    end

    def track_and_log(task, log = true)
      event_log.track(task) do |ticker|
        logger.info(task) if log
        yield ticker if block_given?
      end
    end

    def apply_resolutions(resolutions)
      @resolutions = resolutions
      problems = Models::DeploymentProblem.where(id: resolutions.keys)

      begin_stage('Applying problem resolutions', problems.count)

      problems.each do |problem|
        if problem.state != 'open'
          reason = "state is '#{problem.state}'"
          track_and_log("Ignoring problem #{problem.id} (#{reason})")
        elsif problem.deployment_id != @deployment.id
          reason = 'not a part of this deployment'
          track_and_log("Ignoring problem #{problem.id} (#{reason})")

        else
          apply_resolution(problem)
        end
      end
      @resolved_count
    end

    private

    def apply_resolution(problem)
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

      problem.state = "resolved"
      problem.save
      @resolved_count += 1

    rescue => e
      log_resolution_error(problem, e)
    end

    private

    def log_resolution_error(problem, error)
      logger.error("Error resolving problem `#{problem.id}': #{error}")
      logger.error(error.backtrace.join("\n"))
    end
  end
end
