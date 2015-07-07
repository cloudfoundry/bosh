module Bosh::Monitor
  class Runner
    include YamlHelper

    def self.run(config_file)
      new(config_file).run
    end

    def initialize(config_file)
      Bhm.config = load_yaml_file(config_file)

      @logger        = Bhm.logger
      @director      = Bhm.director
      @intervals     = Bhm.intervals
      @mbus          = Bhm.mbus
      @agent_manager = Bhm.agent_manager
    end

    def run
      @logger.info("HealthMonitor starting...")
      EM.kqueue if EM.kqueue?
      EM.epoll if EM.epoll?

      EM.error_handler { |e| handle_em_error(e) }

      EM.run do
        connect_to_mbus
        @director_monitor = DirectorMonitor.new(Bhm)
        @director_monitor.subscribe
        @agent_manager.setup_events
        setup_timers
        start_http_server
        @logger.info "BOSH HealthMonitor #{Bhm::VERSION} is running..."
      end
    end

    def stop
      @logger.info("HealthMonitor shutting down...")
      @http_server.stop! if @http_server
    end

    def setup_timers
      EM.schedule do
        poll_director
        EM.add_periodic_timer(@intervals.poll_director) { poll_director }
        EM.add_periodic_timer(@intervals.log_stats) { log_stats }

        EM.add_timer(@intervals.poll_grace_period) do
          EM.add_periodic_timer(@intervals.analyze_agents) { analyze_agents }
        end
      end
    end

    def log_stats
      n_deployments = pluralize(@agent_manager.deployments_count, "deployment")
      n_agents = pluralize(@agent_manager.agents_count, "agent")
      @logger.info("Managing #{n_deployments}, #{n_agents}")
      @logger.info("Agent heartbeats received = %s" % [ @agent_manager.heartbeats_received ])
    end

    def connect_to_mbus
      NATS.on_error do |e|
        unless @shutting_down
          if e.kind_of?(NATS::ConnectError)
            handle_em_error(e)
          else
            log_exception(e)
          end
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

    def start_http_server
      @logger.info "HTTP server is starting on port #{Bhm.http_port}..."
      @http_server = Thin::Server.new("127.0.0.1", Bhm.http_port, :signals => false) do
        Thin::Logging.silent = true
        map "/" do
          run Bhm::ApiController.new
        end
      end
      @http_server.start!
    end

    def poll_director
      @logger.debug "Getting deployments from director..."
      Fiber.new { fetch_deployments }.resume
    end

    def analyze_agents
      # N.B. Yes, his will block event loop,
      # possibly consider deferring
      @agent_manager.analyze_agents
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
      @shutting_down = true
      log_exception(e, :fatal)
      stop
    end

    def log_exception(e, level = :error)
      level = :error unless level == :fatal
      @logger.send(level, e.to_s)
      if e.respond_to?(:backtrace) && e.backtrace.respond_to?(:join)
        @logger.send(level, e.backtrace.join("\n"))
      end
    end

    def alert_director_error(message)
      Bhm.event_processor.process(:alert, {
        id: SecureRandom.uuid,
        severity: 3,
        title: 'Health monitor failed to connect to director',
        summary: message,
        created_at: Time.now.to_i,
        source: 'hm'
      })
    end

    def fetch_deployments
      deployments = @director.get_deployments

      @agent_manager.sync_deployments(deployments)

      deployments.each do |deployment|
        deployment_name = deployment["name"]

        @logger.info "Found deployment `#{deployment_name}'"

        @logger.debug "Fetching VMs information for `#{deployment_name}'..."
        vms = @director.get_deployment_vms(deployment_name)

        @agent_manager.sync_agents(deployment_name, vms)
      end

    rescue Bhm::DirectorError => e
      log_exception(e)
      alert_director_error(e.message)
    end
  end
end
