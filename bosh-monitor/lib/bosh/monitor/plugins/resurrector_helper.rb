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

      # Below this number of down agents we don't consider a meltdown occurring
      attr_accessor :minimum_down_jobs

      # Number of seconds at which an alert is considered "current"; alerts older than
      # this are ignored. Integer number of seconds.
      attr_accessor :time_threshold

      # Percentage of the cluster which must be down for scanning to stop. Float fraction
      # between 0 and 1.
      attr_accessor :percent_threshold

      def initialize(args={})
        @agent_manager       = Bhm.agent_manager
        @alert_times         = {} # maps JobInstanceKey to time of last Alert
        @minimum_down_jobs   = args.fetch('minimum_down_jobs', 5)
        @percent_threshold   = args.fetch('percent_threshold', 0.2)
        @time_threshold      = args.fetch('time_threshold', 600)
      end

      # "Melting down" means a large part of the cluster is offline and manual intervention
      # may be required to fix.
      def melting_down?(deployment)
        agent_alerts = alerts_for_deployment(deployment)
        total_number_of_agents = agent_alerts.size
        number_of_down_agents = agent_alerts.select { |_, alert_time|
          alert_time > (Time.now - time_threshold)
        }.size

        return false if number_of_down_agents < minimum_down_jobs

        (number_of_down_agents.to_f / total_number_of_agents) >= percent_threshold
      end

      def record(agent_key, alert_time)
        @alert_times[agent_key] = alert_time
      end

      private

      def alerts_for_deployment(deployment)
        agents = @agent_manager.get_agents_for_deployment(deployment)
        keys = agents.values.map { |agent|
          JobInstanceKey.new(agent.deployment, agent.job, agent.instance_id)
        }

        result = {}
        keys.each { |key| result[key] = @alert_times.fetch(key, Time.at(0)) }
        result
      end
    end
  end
end
