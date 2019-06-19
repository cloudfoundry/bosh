require_relative 'jobs/update_deployment'

module Bosh::Director
  class ProblemResolver
    include DeploymentPlan
    include Jobs

    attr_reader :logger

    def initialize(deployment)
      @deployment = deployment
      @resolved_count = 0
      @resolution_error_logs = StringIO.new
      update_deployment = UpdateDeployment.new(
        @deployment.manifest,
        @deployment.cloud_configs.map(&:id),
        @deployment.runtime_configs.map(&:id),
      )
      @instance_groups = update_deployment.parse_manifest.instance_groups
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
      all_problems = Models::DeploymentProblem.where(id: resolutions.keys, deployment_id: @deployment.id).all
      begin_stage('Applying problem resolutions', all_problems.size)

      if Config.parallel_problem_resolution && all_problems.size > 1
        igs_to_problems = problems_by_instance_group(all_problems)
        partitions_to_problem_igs = partition_instance_groups_by_serial(igs_to_problems.keys)
        process_partitions(partitions_to_problem_igs, igs_to_problems)
      else
        all_problems.each do |problem|
          process_problem(problem)
        end
      end

      error_message = @resolution_error_logs.string.empty? ? nil : @resolution_error_logs.string.chomp

      [@resolved_count, error_message]
    end

    private

    def parallel_each(num_threads, ary)
      if num_threads > 1
        ThreadPool.new(max_threads: num_threads).wrap do |pool|
          ary.each do |entry|
            pool.process do
              yield entry
            end
          end
        end
      else
        ary.each do |entry|
          yield entry
        end
      end
    end

    def process_problem(problem)
      if problem.open?
        apply_resolution(problem)
      else
        track_and_log("Ignoring problem #{problem.id} (state is '#{problem.state}')")
      end
    end

    def partition_instance_groups_by_serial(all_igs_with_problems)
      Hash[
        BatchMultiInstanceGroupUpdater.partition_jobs_by_serial(@instance_groups).map do |ig_partition|
          igs_with_problems = ig_partition.map(&:name).select { |ig_name| all_igs_with_problems.include?(ig_name) }
          [ig_partition, igs_with_problems]
        end
      ]
    end

    def process_partitions(ig_partition_to_ig_names_with_problems, igs_to_problems)
      ig_partition_to_ig_names_with_problems.each do |ig_partition, igs_with_problems|
        num_threads = ig_partition.first.update.serial? ? 1 : [igs_with_problems.size, Config.max_threads].min

        parallel_each(num_threads, igs_with_problems) do |ig_name|
          process_instance_group(ig_name, igs_to_problems[ig_name])
        end
      end
    end

    def process_instance_group(ig_name, problems)
      instance_group = @instance_groups.find do |plan_ig|
        plan_ig.name == ig_name
      end
      max_in_flight = instance_group.update.max_in_flight(problems.size)

      num_threads = [problems.size, max_in_flight, Config.max_threads].min
      parallel_each(num_threads, problems) do |problem|
        process_problem(problem)
      end
    end

    def problems_by_instance_group(problems)
      instance_model_to_problem = lambda do |p|
        begin
          if p.instance_problem?
            return [Models::Instance.where(id: p.resource_id).first, p]
          else
            disk = Models::PersistentDisk.where(id: p.resource_id).first
            return [Models::Instance.where(id: disk.instance_id).first, p] if disk
          end
        rescue StandardError => e
          log_resolution_error(p, e)
        end
      end

      problems
        .map(&instance_model_to_problem)
        .compact
        .each_with_object(Hash.new { [] }) do |(instance_model, problem), ig_name_to_problems|
          ig_name_to_problems[instance_model.job] <<= problem
        end
    end

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
    rescue StandardError => e
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
