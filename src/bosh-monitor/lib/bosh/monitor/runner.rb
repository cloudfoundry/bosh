require 'puma/rack/builder'

module Bosh::Monitor
  class Runner
    include YamlHelper

    def self.run(config_file)
      new(config_file).run
    end

    def initialize(config_file)
      Bosh::Monitor.config = load_yaml_file(config_file)

      @logger        = Bosh::Monitor.logger
      @director      = Bosh::Monitor.director
      @intervals     = Bosh::Monitor.intervals
      @mbus          = Bosh::Monitor.mbus
      @instance_manager = Bosh::Monitor.instance_manager
      @resurrection_manager = Bosh::Monitor.resurrection_manager
    end

    def run
      @logger.info('HealthMonitor starting...')

      Sync do
        connect_to_mbus
        @director_monitor = DirectorMonitor.new(Bosh::Monitor)
        @director_monitor.subscribe
        @instance_manager.setup_events
        start_http_server
        setup_timers
        update_resurrection_config
        @logger.info("BOSH HealthMonitor #{Bosh::Monitor::VERSION} is running...")
      rescue => e
        handle_fatal_error(e)
      end
    end

    def stop
      @logger.info('HealthMonitor shutting down...')
      @http_server&.stop
      # Async gem does not provide a way to get the global Reactor object, but sets it as the Fiber scheduler
      Fiber.scheduler&.close
    end

    def setup_timers
      poll_director
      add_periodic_timer(@intervals.poll_director) { poll_director }
      add_periodic_timer(@intervals.log_stats) { log_stats }
      add_periodic_timer(@intervals.resurrection_config) { update_resurrection_config }

      Async do |task|
        sleep(@intervals.poll_grace_period)
        add_periodic_timer(@intervals.analyze_agents) { analyze_agents }
        add_periodic_timer(@intervals.analyze_instances) { analyze_instances }
      end
    end

    def log_stats
      n_deployments = pluralize(@instance_manager.deployments_count, 'deployment')
      n_agents = pluralize(@instance_manager.agents_count, 'agent')
      @logger.info("Managing #{n_deployments}, #{n_agents}")
      @logger.info(format('Agent heartbeats received = %<heartbeats>s', heartbeats: @instance_manager.heartbeats_received))
    end

    def update_resurrection_config
      @logger.debug('Getting resurrection config from director...')
      Async { fetch_resurrection_config }.wait
    end

    def connect_to_mbus
      Bosh::Monitor.nats = NATS::IO::Client.new

      tls_context = OpenSSL::SSL::SSLContext.new
      tls_context.ssl_version = :TLSv1_2
      tls_context.verify_mode = OpenSSL::SSL::VERIFY_PEER

      tls_context.key = OpenSSL::PKey::RSA.new(File.open(@mbus.client_private_key_path))
      tls_context.cert = OpenSSL::X509::Certificate.new(File.open(@mbus.client_certificate_path))
      tls_context.ca_file = @mbus.server_ca_path

      options = {
        servers: Array.new(1, @mbus.endpoint),
        dont_randomize_servers: true,
        max_reconnect_attempts: 4,
        reconnect_time_wait: 2,
        reconnect: true,
        tls: {
          context: tls_context,
        },
      }

      Bosh::Monitor.nats.on_error do |e|
        unless @shutting_down
          redacted_msg = @mbus.password.nil? ? "NATS client error: #{e}" : "NATS client error: #{e}".gsub(@mbus.password, '*****')
          if e.is_a?(NATS::IO::ConnectError)
            handle_fatal_error(redacted_msg)
          else
            log_exception(redacted_msg)
          end
        end
      end

      Bosh::Monitor.nats.connect(options)
      @logger.info("Connected to NATS at '#{@mbus.endpoint}'")
    end

    def start_http_server
      @logger.info("HTTP server is starting on port #{Bosh::Monitor.http_port}...")
      rack_app = Puma::Rack::Builder.app do
        map '/' do
          run Bosh::Monitor::ApiController.new
        end
      end

      puma_configuration = Puma::Configuration.new do |config|
        config.tag 'bosh_monitor'
        config.bind "tcp://127.0.0.1:#{Bosh::Monitor.http_port}"
        config.app rack_app
        config.preload_app!
      end

      @http_server = Puma::Launcher.new(puma_configuration)
      Async do
        @http_server.run
      end
    end

    def poll_director
      @logger.debug('Getting deployments from director...')
      Async { fetch_deployments }.wait
    end

    def analyze_agents
      # N.B. Yes, this will block event loop,
      # possibly consider deferring
      @instance_manager.analyze_agents
    end

    def analyze_instances
      @instance_manager.analyze_instances
    end

    def handle_fatal_error(err)
      @shutting_down = true
      log_exception(err, :fatal)
      stop
    end

    private

    def add_periodic_timer(interval, &block)
      Async do |task|
        loop do
          sleep(interval)
          yield
        end
      rescue => e
        handle_fatal_error(e)
      end
    end

    def log_exception(err, level = :error)
      level = :error unless level == :fatal
      @logger.send(level, err.to_s)
      @logger.send(level, err.backtrace.join("\n")) if err.respond_to?(:backtrace) && err.backtrace.respond_to?(:join)
    end

    def alert_director_error(message)
      Bosh::Monitor.event_processor.process(
        :alert,
        id: SecureRandom.uuid,
        severity: 3,
        title: 'Health monitor failed to connect to director',
        summary: message,
        created_at: Time.now.to_i,
        source: 'hm',
      )
    end

    def fetch_deployments
      @instance_manager.fetch_deployments(@director)
    rescue Bosh::Monitor::DirectorError => e
      log_exception(e)
      alert_director_error(e.message)
    end

    def fetch_resurrection_config
      @logger.debug('Fetching resurrection config information...')

      resurrection_config = @director.resurrection_config
      @resurrection_manager.update_rules(resurrection_config)
    rescue Bosh::Monitor::DirectorError => e
      log_exception(e)
      alert_director_error(e.message)
    end
  end
end
