module Bosh::Monitor::Plugins
  module ResurrectorHelper
    # Hashable tuple of the identifying properties of a job
    class JobInstanceKey
      attr_accessor :deployment, :job, :id

      def initialize(deployment, job, id)
        @deployment = deployment
        @job        = job
        @id         = id
      end

      def hash
        (deployment.to_s + job.to_s + id.to_s).hash
      end

      def eql?(other)
        other.deployment == deployment &&
          other.job == job &&
          other.id == id
      end

      def to_s
        [deployment, job, id].join('/')
      end
    end

    # Service which tracks alerts and decides whether or not the cluster is melting down.
    # When the cluster is melting down, the resurrector backs off on fixing instances.
    class AlertTracker
      UNHEALTHY = [:critical].freeze

      # Below this number of down agents we don't consider a meltdown occurring
      attr_accessor :minimum_down_jobs

      # Number of seconds at which an alert is considered "current"; alerts older than
      # this are ignored. Integer number of seconds.
      attr_accessor :time_threshold

      # Percentage of the cluster which must be down for scanning to stop. Float fraction
      # between 0 and 1.
      attr_accessor :percent_threshold

      def initialize(args = {})
        @instance_manager  = Bosh::Monitor.instance_manager
        @unhealthy_agents  = {}
        @minimum_down_jobs = args.fetch('minimum_down_jobs', 5)
        @percent_threshold = args.fetch('percent_threshold', 0.2)
        @time_threshold    = args.fetch('time_threshold', 600)
      end

      def record(agent_key, alert)
        @unhealthy_agents[agent_key] = alert.created_at if UNHEALTHY.include?(alert.severity)
      end

      def state_for(deployment)
        # do not forget about instances with deleted vm, which expect to have vm
        agents = @instance_manager.get_agents_for_deployment(deployment).values +
                 @instance_manager.get_deleted_agents_for_deployment(deployment).values
        unhealthy_count = unhealthy_count(agents)

        DeploymentState.new(deployment, agents.count, unhealthy_count,
                            count_threshold: minimum_down_jobs,
                            percent_threshold: percent_threshold)
      end

      private

      def unhealthy_count(agents)
        count = 0

        agents.each do |agent|
          key = JobInstanceKey.new(agent.deployment, agent.job, agent.instance_id)

          next unless (time = @unhealthy_agents.fetch(key, false))

          t1 = time.to_i
          t2 = (Time.now - time_threshold).to_i
          count += 1 if t1 >= t2
        end

        count
      end
    end

    class DeploymentState
      STATE_NORMAL = 'normal'.freeze
      STATE_MANAGED = 'managed'.freeze
      STATE_MELTDOWN = 'meltdown'.freeze

      def initialize(deployment, agent_count, unhealthy_count, thresholds)
        @deployment = deployment
        @agent_count = agent_count
        @unhealthy_count = unhealthy_count
        @count_threshold = thresholds[:count_threshold]
        @percent_threshold = thresholds[:percent_threshold]
      end

      def managed?
        state == STATE_MANAGED
      end

      def meltdown?
        state == STATE_MELTDOWN
      end

      def normal?
        state == STATE_NORMAL
      end

      def summary
        "deployment: '#{@deployment}'; #{@unhealthy_count} of #{@agent_count} agents are unhealthy (#{(unhealthy_percent * 100).round(1)}%)"
      end

      private

      def state
        if @unhealthy_count > 0
          return STATE_MELTDOWN if @unhealthy_count >= @count_threshold && unhealthy_percent >= @percent_threshold

          return STATE_MANAGED
        end

        STATE_NORMAL
      end

      def unhealthy_percent
        @unhealthy_percent ||= (@unhealthy_count.to_f / @agent_count)
      end
    end
  end
end
