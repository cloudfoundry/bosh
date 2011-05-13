module Bosh::HealthMonitor
  class Runner
    include YamlHelper

    def self.run(config_file)
      new(config_file).run
    end

    def initialize(config_file)
      Bhm.config = load_yaml_file(config_file)

      @logger    = Bhm.logger
      @director  = Bhm.director
      @intervals = Bhm.intervals
      @mbus      = Bhm.mbus

      # Things to manage:
      @deployment_manager = DeploymentManager.new
      @agent_manager      = AgentManager.new
    end

    def run
      @logger.info("HealthMonitor starting...")
      EM.kqueue if EM.kqueue?
      EM.epoll  if EM.epoll?

      EM.error_handler { |e| handle_em_error(e) }

      EM.run do
        connect_to_mbus
        @agent_manager.setup_subscriptions
        setup_timers
        @logger.info "Bosh HealthMonitor #{Bhm::VERSION} is running..."
      end
    end

    def stop(e = nil)
      EM.stop
      @logger.info("HealthMonitor shutting down...")
      if e.kind_of?(Exception) # Re-raise exception to see the error on tty as well
        raise e
      else
        exit(1)
      end
    end

    def setup_timers
      EM.next_tick do
        poll_director
        EM.add_periodic_timer(@intervals.poll_director) { poll_director }
        EM.add_periodic_timer(@intervals.log_stats) { log_stats }
      end
    end

    def log_stats
      @logger.info("Managing %s, %s" % [ pluralize(@deployment_manager.deployments_count, "deployment"), pluralize(@agent_manager.agents_count, "agent") ])
      @logger.info("Agent requests sent = %s, replies received = %s" % [ @agent_manager.requests_sent, @agent_manager.replies_received ])
    end

    def connect_to_mbus
      NATS.on_error do |e|
        case e
        when NATS::ConnectError
          log_exception(e, :fatal)
          stop(e)
        else
          log_exception(e)
        end
      end

      nats_client_options = {
        :uri       => @mbus.endpoint,
        :user      => @mbus.user,
        :pass      => @mbus.password,
        :autostart => false
      }

      Bhm.nats = NATS.connect(nats_client_options) do
        @logger.info("Connected to NATS at `#{@mbus.endpoint}'")
      end
    end

    def poll_director
      @logger.debug "Getting deployments from director..."
      Fiber.new { fetch_deployments }.resume
    end

    private

    # This is somewhat controversial approach: instead of swallowing some exceptions
    # and letting event loop run further we force our server to stop. The rationale
    # behind that is to avoid the situation when swallowed exception actually breaks
    # things:
    # 1. Periodic timer will get canceled unless we manually reschedule it
    #    in a rescue clause even if we swallow the exception.
    # 2. If we want to perform an operation on next tick AND schedule some operation
    #    to be run periodically AND there is an exception swallowed somewhere during the
    #    event processing, then on the next tick we don't really process events that follow the buggy one.
    # These things can be pretty painful for HM as we might think it runs fine
    # when it actually just swallows some exception and effectively does nothing.
    # We might revisit that later
    def handle_em_error(e)
      log_exception(e, :fatal)
      stop(e)
    end

    def log_exception(e, level = :error)
      level = :error unless level == :error || level == :fatal
      @logger.send(level, e.to_s)
      if e.respond_to?(:backtrace) && e.backtrace.respond_to?(:join)
        @logger.send(level, e.backtrace.join("\n"))
      end
    end

    def fetch_deployments
      deployments = @director.get_deployments

      deployments.each do |deployment|
        deployment_name = deployment["name"]

        @logger.info "Found deployment `#{deployment_name}'"

        deployment_info = @director.get_deployment(deployment_name)
        @logger.debug "Updated deployment information for `#{deployment_name}'"

        @deployment_manager.update_deployment(deployment_name, deployment_info)
        # TODO: handle missing deployments

        if deployment_info["vms"].kind_of?(Array)
          deployment_info["vms"].each do |vm|
            @agent_manager.update_agent(deployment_name, vm["agent_id"])
            # TODO: handle missing agents
          end
        else
          @logger.warn "Cannot get VMs list from deployment, possibly the old director version"
        end
      end
    rescue Bhm::DirectorError => e
      log_exception(e)
    end

  end
end
