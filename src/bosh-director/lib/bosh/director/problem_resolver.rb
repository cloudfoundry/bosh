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
        ig_to_problems = problems_by_instance_group(all_problems)

        problems_serially_ordered_by_job(ig_to_problems) do |ig_problems, max_in_flight|
          n_threads = [ig_problems.size, max_in_flight, Config.max_threads].min
          parallel_each(n_threads, ig_problems) do |problem|
            process_problem(problem)
          end
        end
      else
        all_problems.each do |problem|
          process_problem(problem)
        end
      end

      error_message = @resolution_error_logs.string.empty? ? nil : @resolution_error_logs.string.chomp

      [@resolved_count, error_message]
    end

    private

    def parallel_each(n_threads, ary)
      if n_threads > 1
        ThreadPool.new(max_threads: n_threads).wrap do |pool|
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

    def problems_serially_ordered_by_job(ig_to_problems, &block)
      BatchMultiInstanceGroupUpdater.partition_jobs_by_serial(@instance_groups).each do |jp|
        igs_with_problems = []
        jp.each { |ig| igs_with_problems << ig.name if ig_to_problems.key?(ig.name) }
        n_threads = [igs_with_problems.size, Config.max_threads].min
        parallel_each(jp.first.update.serial? ? 1 : n_threads, igs_with_problems) do |ig_name|
          process_ig(ig_name, ig_to_problems[ig_name], block)
        end
      end
    end

    def process_ig(ig_name, problems, block)
      instance_group = @instance_groups.find do |plan_ig|
        plan_ig.name == ig_name
      end
      max_in_flight = instance_group.update.max_in_flight(problems.size)
      block.call(problems, max_in_flight)
    end

    def problems_by_instance_group(problems)
      instance_group_to_problems = {}
      problems.each do |p|
        begin
          if p.instance_problem?
            instance = Models::Instance.where(id: p.resource_id).first
          else
            disk = Models::PersistentDisk.where(id: p.resource_id).first
            instance = Models::Instance.where(id: disk.instance_id).first if disk
          end
          (instance_group_to_problems[instance.job] ||= []) << p if instance
        rescue StandardError => e
          log_resolution_error(p, e)
        end
      end
      instance_group_to_problems
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
