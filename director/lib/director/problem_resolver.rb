# -*- encoding: utf-8 -*-
# Copyright (c) 2013 GoPivotal, Inc.

module Bosh::Director
  class ProblemResolver

    attr_reader :event_log, :logger

    ##
    # Creates a new Bosh::Director::ProblemResolver instance
    #
    # @param [Bosh::Director::Models::Deployment] deployment Deployment
    # @return [Bosh::Director::ProblemResolver] ProblemResolver instance
    def initialize(deployment)
      @deployment = deployment

      @event_log = Config.event_log
      @logger = Config.logger
    end

    ##
    # Apply resolutions to existing problems
    #
    # @param [Hash] resolutions Resolutions to apply
    # @return [Integer] Number of resolved problems
    def apply_resolutions(resolutions)
      @resolved_count = 0

      begin_stage('Applying problem resolutions', resolutions.size)
      problems = get_open_problems(resolutions)
      problems.each do |problem|
        apply_resolution(problem, resolutions[problem.id.to_s])
      end

      log_ignored_resolutions(resolutions, problems)

      @resolved_count
    end

    private

    ##
    # Get the list of open problems for the deployment
    #
    # @param [Hash] resolutions Resolutions to apply
    # @return [Array<Bosh::Director::Models::DeploymentProblem>] Open deployment problems
    # @raise [Bosh::Director::CloudcheckResolutionNotProvided] If there's a deployment problem without resolution
    def get_open_problems(resolutions)
      problems = Models::DeploymentProblem.filter(deployment: @deployment, state: 'open').all

      problems.each do |problem|
        unless resolutions.key?(problem.id.to_s)
          raise CloudcheckResolutionNotProvided,
                "Resolution for problem #{problem.id} (#{problem.type}) is not provided"
        end
      end
    end

    ##
    # Apply a resolution to an existing problem
    #
    # @param [Bosh::Director::Models::DeploymentProblem] problem Deployment problem
    # @param [Hash] resolution Resolution for the deployment problem
    # @return [void]
    def apply_resolution(problem, resolution)
      handler = ProblemHandlers::Base.create_from_model(problem)
      handler.job = self

      resolution = resolution || handler.auto_resolution
      resolution_summary = handler.resolution_plan(resolution) || 'no resolution'

      desc = "#{problem.type} #{problem.resource_id}: #{resolution_summary}"
      begin
        track_and_log("#{desc}") do
          handler.apply_resolution(resolution)
        end
      rescue Bosh::Director::ProblemHandlerError => e
        log_resolution_error(problem, e)
      end

      problem.state = 'resolved'
      problem.save
      @resolved_count += 1
    rescue => e
      log_resolution_error(problem, e)
    end

    # We might have some resolutions for problems that are no longer open or just some bogus problem ids,
    # in that case we still need to mention them in event log so end user understands what actually happened.
    #
    # @param [Hash] resolutions Resolutions to apply
    # @param [Array<Bosh::Director::Models::DeploymentProblem>] Open deployment problems
    # @return [void]
    def log_ignored_resolutions(resolutions, problems)
      resolutions_ignored = resolutions.keys.to_set - problems.map { |problem| problem.id }.to_set
      resolutions_ignored.each do |problem_id|
        if problem_id !~ /^\d+$/
          reason = 'malformed id'
        else
          problem = Models::DeploymentProblem[problem_id.to_i]
          if problem.nil?
            reason = 'not found'
          elsif problem.state != 'open'
            reason = "state is '#{problem.state}'"
          elsif problem.deployment_id != @deployment.id
            reason = 'not a part of this deployment'
          else
            reason = 'reason unknown'
          end
        end

        track_and_log("Ignoring problem #{problem_id} (#{reason})") { }
      end
    end

    ##
    # Begins a stage
    #
    # @param [String] stage_name Name of Stage
    # @parma [Integer] n_steps Number of steps in stage
    # @return [void]
    def begin_stage(stage_name, n_steps)
      event_log.begin_stage(stage_name, n_steps)
      logger.info(stage_name)
    end

    ##
    # Tracks a task in stage
    #
    # @param [String] task Task name
    # @return [void]
    def track_and_log(task)
      event_log.track(task) do |ticker|
        logger.info(task)
        yield ticker if block_given?
      end
    end

    ##
    # Log a resolution error
    #
    # @param [Bosh::Director::Models::DeploymentProblem] problem Deployment problem
    # @param [Exception] error Exception
    # @return [void]
    def log_resolution_error(problem, error)
      logger.error("Error resolving problem `#{problem.id}': #{error}")
      logger.error(error.backtrace.join("\n"))
    end
  end
end
