module Bosh::Agent

  class Handler
    attr_reader :processors

    def self.start
      new.start
    end

    MAX_NATS_RETRIES = 10
    NATS_RECONNECT_SLEEP = 0.5

    def initialize
      @agent_id  = Config.agent_id
      @logger    = Config.logger
      @nats_uri  = Config.mbus
      @base_dir  = Config.base_dir

      # Alert processing
      @process_alerts = Config.process_alerts
      @smtp_user      = Config.smtp_user
      @smtp_password  = Config.smtp_password
      @smtp_port      = Config.smtp_port

      @hbp = Bosh::Agent::HeartbeatProcessor.new

      @lock = Mutex.new

      @results = []
      @long_running_agent_task = []

      @nats_fail_count = 0

      find_message_processors
    end

    # TODO: add runtime loading of messag handlers
    def find_message_processors
      message_consts = Bosh::Agent::Message.constants
      @processors = {}
      message_consts.each do |c|
        klazz = Bosh::Agent::Message.const_get(c)
        if klazz.respond_to?(:process)
          # CamelCase -> under_score -> downcased
          processor_key = c.to_s.gsub(/(.)([A-Z])/,'\1_\2').downcase
          @processors[processor_key] = klazz
        end
      end
      @logger.info("Message processors: #{@processors.inspect}")
    end

    def lookup(method)
      @processors[method]
    end

    def start
      ['TERM', 'INT', 'QUIT'].each { |s| trap(s) { shutdown } }

      EM.run do
        begin
          @nats = NATS.connect(:uri => @nats_uri, :autostart => false) { on_connect }
          Config.nats = @nats
        rescue Errno::ENETUNREACH, Timeout::Error => e
          @logger.info("Unable to talk to nats - retry (#{e.inspect})")
          sleep 0.1
          retry
        end

        setup_heartbeats
        setup_sshd_monitor

        if @process_alerts
          if (@smtp_port.nil? || @smtp_user.nil? || @smtp_password.nil?)
            @logger.error "Cannot start alert processor without having SMTP port, user and password configured"
            @logger.error "Agent will be running but alerts will NOT be properly processed"
          else
            @logger.debug("SMTP: #{@smtp_password}")
            @processor = Bosh::Agent::AlertProcessor.start("127.0.0.1", @smtp_port, @smtp_user, @smtp_password)
          end
        end
      end
    rescue NATS::ConnectError => e
      @nats_fail_count += 1
      @logger.error("NATS connection error: #{e.message}")
      sleep NATS_RECONNECT_SLEEP
      # only retry a few times and then exit which lets the agent recover if we change credentials
      retry if @nats_fail_count < MAX_NATS_RETRIES
      @logger.fatal("Unable to reconnect to NATS after #{MAX_NATS_RETRIES} retries, exiting...")
    end

    def shutdown
      @logger.info("Exit")
      NATS.stop { EM.stop; exit }
    end

    def on_connect
      subscription = "agent.#{@agent_id}"
      @nats.subscribe(subscription) { |raw_msg| handle_message(raw_msg) }
      @nats_fail_count = 0
    end

    def setup_heartbeats
      interval = Config.heartbeat_interval.to_i
      if interval > 0
        @hbp.enable(interval)
        @logger.info("Heartbeats are enabled and will be sent every #{interval} seconds")
      else
        @logger.warn("Heartbeats are disabled")
      end
    end

    def setup_sshd_monitor
      interval = Config.sshd_monitor_interval.to_i
      if interval > 0
        Bosh::Agent::SshdMonitor.enable(interval, Config.sshd_start_delay)
        @logger.info("sshd monitor is enabled, interval of #{interval} and start " +
                     "delay of #{Config.sshd_start_delay} seconds")
      else
        @logger.warn("SSH is disabled")
      end
    end

    def handle_message(json)
      begin
        msg = Yajl::Parser.new.parse(json)
      rescue Yajl::ParseError => e
        @logger.info("Failed to parse message: #{json}: #{e.inspect}: #{e.backtrace}")
        return
      end

      @logger.info("Message: #{msg.inspect}")

      reply_to = msg['reply_to']
      method   = msg['method']
      args     = msg['arguments']

      if method == "get_state"
        method = "state"
      end

      processor = lookup(method)
      if processor
        Thread.new {
          if processor.respond_to?(:long_running?)
            if @long_running_agent_task.empty?
              process_long_running(reply_to, processor, args)
            else
              payload = {:exception => "already running long running task"}
              publish(reply_to, payload)
            end
          else
            payload = process(processor, args)

            if Config.configure && method == 'prepare_network_change'
              publish(reply_to, payload) {
                post_prepare_network_change
              }
            else
              publish(reply_to, payload)
            end

          end
        }
      elsif method == "get_task"
        handle_get_task(reply_to, args.first)
      elsif method == "shutdown"
        handle_shutdown(reply_to)
      else
        payload = {:exception => "unknown message #{msg.inspect}"}
        publish(reply_to, payload)
      end
    end

    def handle_get_task(reply_to, agent_task_id)
      if @long_running_agent_task == [agent_task_id]
        publish(reply_to, {"value" => {"state" => "running", "agent_task_id" => agent_task_id}})
      else
        rs = @results.find { |time, task_id, result| task_id == agent_task_id }
        if rs
          time, task_id, result = rs
          publish(reply_to, result)
        else
          publish(reply_to, {"exception" => "unknown agent_task_id" })
        end
      end
    end

    def publish(reply_to, payload, &blk)
      @logger.info("reply_to: #{reply_to}: payload: #{payload.inspect}")
      @nats.publish(reply_to, Yajl::Encoder.encode(payload), blk)
    end

    def process_long_running(reply_to, processor, args)
      agent_task_id = generate_agent_task_id

      @lock.synchronize do
        @long_running_agent_task = [agent_task_id]
      end

      payload = {:value => {:state => "running", :agent_task_id => agent_task_id}}
      publish(reply_to, payload)

      begin
        result = process(processor, args)
      ensure
        @lock.synchronize do
          @results << [Time.now.to_i, agent_task_id, result]
          @long_running_agent_task = []
        end
      end
    end

    def process(processor, args)
      begin
        result = processor.process(args)
        return {:value => result}
      rescue Bosh::Agent::MessageHandlerError => e
        @logger.info("#{e.inspect}: #{e.backtrace}")
        return {:exception => "#{e.inspect}: #{e.backtrace}"}
      rescue Exception => e
        @logger.info("#{e.inspect}: #{e.backtrace}")
        raise e
      end
    end

    def generate_agent_task_id
      UUIDTools::UUID.random_create.to_s
    end

    def post_prepare_network_change
      if Bosh::Agent::Config.configure
        udev_file = '/etc/udev/rules.d/70-persistent-net.rules'
        if File.exist?(udev_file)
          @logger.info("deleting 70-persistent-net.rules - again")
          `rm #{udev_file}`
        end
        @logger.info("Removing settings.json")
        settings_file = Bosh::Agent::Config.settings_file
        `rm #{settings_file}`
      end

      @logger.info("Halt after networking change")
      `/sbin/halt`
    end

    def handle_shutdown(reply_to)
      @logger.info("Shutting down #{URI.parse(Config.mbus).scheme.upcase} connection")
      payload = {:value => "shutdown"}

      if Bosh::Agent::Config.configure
        # We should never come back up again
        at_exit { `sv stop agent` }
      end

      publish(reply_to, payload) {
        shutdown
      }
    end

  end

  # Built-in message handlers
  module Message

    class Ping
      def self.process(args)
        "pong"
      end
    end

    class Noop
      def self.process(args)
        "nope"
      end
    end

    class Start
      def self.process(args)

        if Config.configure
          Bosh::Agent::Monit.start_services
        end

        "started"

      rescue => e
        raise Bosh::Agent::MessageHandlerError, "Cannot start job: #{e}"
      end
    end

    # FIXME: temporary stop method
    class Stop
      def self.process(args)

        if Config.configure
          Bosh::Agent::Monit.stop_services
        end

        "stopped"

      rescue => e
        # Monit retry logic should make it really hard to get here but if it happens we should yell.
        # One potential problem is that drain process might have unmonitored and killed processes
        # already but Monit became really unresponsive. In that case it might be a fake alert:
        # however this is not common and can be handled on case-by-case basis.
        raise Bosh::Agent::MessageHandlerError, "Cannot stop job: #{e}"
      end
    end

    class PrepareNetworkChange
      def self.process(args)
        true
      end
    end

  end

end
