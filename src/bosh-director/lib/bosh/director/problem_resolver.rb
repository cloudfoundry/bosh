module Bosh::Director
  class ProblemResolver
    include LegacyDeploymentHelper

    attr_reader :logger

    def initialize(deployment)
      @deployment = deployment
      @resolved_count = 0
      @resolution_error_logs = StringIO.new

      #temp
      @event_log_stage = nil
      @logger = Config.logger
    end

    def begin_stage(stage_name, n_steps)
      @event_log_stage = Config.event_log.begin_stage(stage_name, n_steps)
      logger.info(stage_name)
    end

    def track_and_log(task, log = true)
      @event_log_stage.advance_and_track(task) do |ticker|
        logger.info(task) if log
        yield ticker if block_given?
      end
    end

    def apply_resolutions(resolutions)
      @resolutions = resolutions
      problems = Models::DeploymentProblem.where(id: resolutions.keys)

      begin_stage('Applying problem resolutions', problems.count)

      # TODO: here we just assume :type recreate VM,
      # make sure that other problem types like re-attach disk still work
      problems_ordered_by_job(problems.all) do |probs, max_in_flight|
        number_of_threads = [probs.size, max_in_flight].min
        ThreadPool.new(max_threads: number_of_threads).wrap do |pool|
          probs.each do |problem|
            pool.process do
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
          end
        end
      end

      error_message = @resolution_error_logs.string.empty? ? nil : @resolution_error_logs.string.chomp

      [@resolved_count, error_message]
    end

    private

    def problems_ordered_by_job(problems, &block)
      partition_jobs_by_serial(deployment_plan.instance_groups).each do |jp|
        if jp.first.update.serial?
          # all instance groups in this partition are serial
          jp.each do |ig|
            process_ig(ig, problems, block)
          end
        else
          # all instance groups in this partition are non-serial
          # therefore, parallelize recreation of all instances in this partition
          # therefore, create an outer ThreadPool as ParallelMultiInstanceGroupUpdater does it in the regular deploy flow

          # TODO: might not want to create a new thread for instance_groups without problems
          ThreadPool.new(max_threads: jp.size).wrap do |pool|
            jp.each do |ig|
              pool.process do
                process_ig(ig, problems, block)
              end
            end
          end
        end
      end
    end

    def process_ig(ig, problems, block)
      instance_group = deployment_plan.instance_groups.find do |plan_ig|
        plan_ig.name == ig.name
      end
      probs = select_problems_by_instance_group(problems, ig)
      max_in_flight = instance_group.update.max_in_flight(probs.size)
      # within an instance_group parallelize recreation of all instances
      block.call(probs, max_in_flight)
    end

    def select_problems_by_instance_group(problems, instance_group)
      problems.select do |p|
        # TODO do not select the instance of every problem
        # instead: push the instance_group.name condition to the database (by a second where clause?)
        instance = Models::Instance.where(:id=>p.resource_id).first # resource_id corresponds to the primary key of the instances table
        instance.job == instance_group.name
      end
    end

    # TODO this method is copied from src/bosh-director/lib/bosh/director/deployment_plan/multi_instance_group_updater.rb
    # reuse code instead
    def partition_jobs_by_serial(jobs)
      job_partitions = []
      last_partition = []

      jobs.each do |j|
        lastj = last_partition.last
        if !lastj || lastj.update.serial? == j.update.serial?
          last_partition << j
        else
          job_partitions << last_partition
          last_partition = [j]
        end
      end

      job_partitions << last_partition if last_partition.any?
      job_partitions
    end

    # TODO >>>>>> below methods are copied from src/bosh-director/lib/bosh/director/jobs/update_deployment.rb
    # resuse code instead
    def deployment_plan
      return @deployment_plan if @deployment_plan

      deployment_manifest = Manifest.load_from_hash(manifest_hash, @deployment.manifest, cloud_config_models, runtime_config_models)
      planner_factory = DeploymentPlan::PlannerFactory.create(logger)

      @deployment_plan = planner_factory.create_from_manifest(
        deployment_manifest,
        cloud_config_models,
        runtime_config_models,
        {}, # @options,
      )
    end

    def cloud_config_models
      return @cloud_config_models if @cloud_config_models

      if ignore_cloud_config?(manifest_hash)
        warning = "Ignoring cloud config. Manifest contains 'networks' section."
        logger.debug(warning)
        # @event_log.warn_deprecated(warning)
        @cloud_config_models = nil
      else
        @cloud_config_models = Bosh::Director::Models::Config.find_by_ids(@deployment.cloud_configs.map(&:id))
        if cloud_config_models.empty?
          logger.debug('No cloud config uploaded yet.')
        else
          logger.debug("Cloud config:\n#{Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_config_models).raw_manifest}")
        end
      end

      @cloud_config_models
    end

    def runtime_config_models
      return @runtime_config_models if @runtime_config_models

      @runtime_config_models = Bosh::Director::Models::Config.find_by_ids(@deployment.runtime_configs.map(&:id))
      if runtime_config_models.empty?
        logger.debug("No runtime config uploaded yet.")
      else
        logger.debug("Runtime configs:\n#{Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_config_models).raw_manifest}")
      end
      @runtime_config_models
    end

    def manifest_hash
      return @manifest_hash if @manifest_hash

      logger.info('Reading deployment manifest')
      @manifest_hash = YAML.load(@deployment.manifest)
      logger.debug("Manifest:\n#{@deployment.manifest}")
      @manifest_hash
    end
    # <<<<<<<< copied up until here

    def apply_resolution(problem)
      handler = ProblemHandlers::Base.create_from_model(problem)
      handler.job = self

      resolution = @resolutions[problem.id.to_s] || handler.auto_resolution
      problem_summary = "#{problem.type} #{problem.resource_id}"
      resolution_summary = handler.resolution_plan(resolution)
      resolution_summary ||= 'no resolution'

      begin
        track_and_log("#{problem.description} (#{problem_summary}): #{resolution_summary}") do
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

    def log_resolution_error(problem, error)
      error_message = "Error resolving problem '#{problem.id}': #{error}"
      logger.error(error_message)
      logger.error(error.backtrace.join("\n"))
      @resolution_error_logs.puts(error_message)
    end
  end
end
