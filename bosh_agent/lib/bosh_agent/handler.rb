module Bosh::Agent

  class Handler
    include Bosh::Exec

    attr_accessor :current_long_running_task
    attr_accessor :nats
    attr_reader :processors

    def self.start
      new.start
    end

    MAX_NATS_RETRIES = 10
    NATS_RECONNECT_SLEEP = 0.5

    # Seconds  until we kill the agent so it can be restarted:
    KILL_AGENT_THREAD_TIMEOUT_ON_ERRORS = 15 # When there's an unexpected error
    KILL_AGENT_THREAD_TIMEOUT_ON_RESTART = 1 # When we force a restart

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
      self.current_long_running_task = {}
      @restarting_agent = false

      @nats_fail_count = 0

      @credentials = Config.credentials
      @sessions = {}
      @session_reply_map = {}

      find_message_processors
    end

    def find_message_processors
      message_consts = Bosh::Agent::Message.constants
      @processors = {}
      message_consts.each do |c|
        klazz = Bosh::Agent::Message.const_get(c)
        if klazz.respond_to?(:process)
          # CamelCase -> under_score -> downcased
          processor_key = c.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase
          @processors[processor_key] = klazz
        end
      end
      @logger.info("Message processors: #{@processors.inspect}")
    end

    def lookup(method)
      @processors[method]
    end

    # rubocop:disable MethodLength
    def start
      %w(TERM INT QUIT).each { |s| trap(s) { shutdown } }

      EM.run do
        begin
          @nats = NATS.connect(uri: @nats_uri, autostart: false) { on_connect }
          Config.nats = @nats
        rescue Errno::ENETUNREACH, Timeout::Error => e
          @logger.info("Unable to talk to nats - retry (#{e.inspect})")
          sleep 0.1
          retry
        end

        setup_heartbeats

        if @process_alerts
          if @smtp_port.nil? || @smtp_user.nil? || @smtp_password.nil?
            @logger.error 'Cannot start alert processor without having SMTP port, user and password configured'
            @logger.error 'Agent will be running but alerts will NOT be properly processed'
          else
            @logger.debug("SMTP: #{@smtp_password}")
            @processor = Bosh::Agent::AlertProcessor.start('127.0.0.1', @smtp_port, @smtp_user, @smtp_password)
            setup_syslog_monitor
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
    # rubocop:enable MethodLength

    def shutdown
      @logger.info('Exit')
      NATS.stop do
        EM.stop
        exit
      end
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
        @logger.warn('Heartbeats are disabled')
      end
    end

    def setup_syslog_monitor
      Bosh::Agent::SyslogMonitor.start(@nats, @agent_id)
    end

    # rubocop:disable MethodLength
    def handle_message(json)
      msg = Yajl::Parser.new.parse(json)

      unless msg['reply_to']
        @logger.info("Missing reply_to in: #{msg}")
        return
      end

      @logger.info("Message: #{msg.inspect}")

      if @credentials
        msg = decrypt(msg)
        return if msg.nil?
      end

      reply_to = msg['reply_to']
      method = msg['method']
      args = msg['arguments']

      if method == 'get_state'
        method = 'state'
      end

      processor = lookup(method)
      if processor
        EM.defer do
          process_in_thread(processor, reply_to, method, args)
        end
      elsif method == 'cancel_task'
        handle_cancel_task(reply_to, args.first)
      elsif method == 'get_task'
        handle_get_task(reply_to, args.first)
      elsif method == 'shutdown'
        handle_shutdown(reply_to)
      else
        re = RemoteException.new("unknown message #{msg.inspect}")
        publish(reply_to, re.to_hash)
      end
    rescue Yajl::ParseError => e
      @logger.info("Failed to parse message: #{json}: #{e.inspect}: #{e.backtrace}")
    end
    # rubocop:enable MethodLength

    # rubocop:disable MethodLength
    def process_in_thread(processor, reply_to, method, args)
      if processor.respond_to?(:long_running?)
        if @restarting_agent
          exception = RemoteException.new('restarting agent')
          publish(reply_to, exception.to_hash)
        else
          @lock.synchronize do
            if current_long_running_task[:task_id]
              exception = RemoteException.new('already running long running task')
              publish(reply_to, exception.to_hash)
            else
              process_long_running(reply_to, processor, args)
            end
          end
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
    rescue => e
      # since this is running in a thread we're going to be nice and
      # log an error as this would otherwise be lost
      @logger.error("#{processor.to_s}: #{e.message}\n#{e.backtrace.join("\n")}")
    end
    # rubocop:enable MethodLength

    def handle_cancel_task(reply_to, agent_task_id)
      if current_long_running_task?(agent_task_id)
        if current_long_running_task[:processor].respond_to?(:cancel)
          current_long_running_task[:processor].cancel
          publish(reply_to, { 'value' => 'canceled' })
          self.current_long_running_task = {}
        else
          publish(reply_to, { 'exception' => "could not cancel task #{agent_task_id}" })
        end
      else
        publish(reply_to, { 'exception' => 'unknown agent_task_id' })
      end
    end

    def handle_get_task(reply_to, agent_task_id)
      if current_long_running_task?(agent_task_id)
        publish(reply_to, { 'value' => { 'state' => 'running', 'agent_task_id' => agent_task_id } })
      else
        rs = @results.find { |time, task_id, result| task_id == agent_task_id }
        if rs
          _, _, result = rs
          publish(reply_to, result)
        else
          publish(reply_to, { 'exception' => 'unknown agent_task_id' })
        end
      end
    end

    NATS_MAX_PAYLOAD_SIZE = 1024 * 1024

    def publish(reply_to, payload, &blk)
      @logger.info("reply_to: #{reply_to}: payload: #{payload.inspect}")

      unencrypted = payload
      if @credentials
        payload = encrypt(reply_to, payload)
      end

      json = Yajl::Encoder.encode(payload)

      if json.bytesize < NATS_MAX_PAYLOAD_SIZE
        EM.next_tick do
          @nats.publish(reply_to, json, &blk)
        end
      else
        msg = 'message > NATS_MAX_PAYLOAD, stored in blobstore'
        exception = RemoteException.new(msg, nil, unencrypted)
        @logger.fatal(msg)
        EM.next_tick do
          @nats.publish(reply_to, Yajl::Encoder.encode(exception.to_hash), &blk)
        end
      end
    end

    def process_long_running(reply_to, processor, args)
      agent_task_id = generate_agent_task_id

      self.current_long_running_task = { task_id: agent_task_id, processor: processor }

      payload = { value: { state: 'running', agent_task_id: agent_task_id } }
      publish(reply_to, payload)

      result = process(processor, args)
      @results << [Time.now.to_i, agent_task_id, result]
      self.current_long_running_task = {}
    end

    def kill_main_thread_in(seconds)
      @restarting_agent = true
      Thread.new do
        sleep(seconds)
        Thread.main.terminate
      end
    end

    def process(processor, args)
      result = processor.process(args)
      return { value: result }
    rescue Bosh::Agent::Error => e
      @logger.info("#{e.inspect}: #{e.backtrace}")
      return RemoteException.from(e).to_hash
    # rubocop:disable RescueException
    rescue Exception => e
    # rubocop:enable RescueException
      kill_main_thread_in(KILL_AGENT_THREAD_TIMEOUT_ON_ERRORS)
      @logger.error("#{e.inspect}: #{e.backtrace}")
      return { exception: "#{e.inspect}: #{e.backtrace}" }
    end

    def generate_agent_task_id
      SecureRandom.uuid
    end

    ##
    # When there's a network change on an existing vm, director sends a prepare_network_change message to the vm
    # agent. After agent replies to director with a `true` message, the post_prepare_network_change method is called
    # (via EM callback).
    #
    # The post_prepare_network_change  method will delete the udev network persistent rules, delete the agent settings
    # and then it should restart the agent to get the new agent settings (set by director-cpi). For a simple network
    # change (i.e. dns changes) this is enough, as when the agent is restarted it will apply the new network settings.
    # But for other network changes (i.e. IP change), the CPI will be responsible to reboot or recreate the vm if
    # needed.
    def post_prepare_network_change
      if Bosh::Agent::Config.configure
        udev_file = '/etc/udev/rules.d/70-persistent-net.rules'
        if File.exist?(udev_file)
          @logger.info('deleting 70-persistent-net.rules - again')
          File.delete(udev_file)
        end
        @logger.info('Removing settings.json')
        settings_file = Bosh::Agent::Config.settings_file
        File.delete(settings_file)
      end

      @logger.info('Restarting agent to prepare for a network change')
      kill_main_thread_in(KILL_AGENT_THREAD_TIMEOUT_ON_RESTART)
    end

    def handle_shutdown(reply_to)
      @logger.info("Shutting down #{URI.parse(Config.mbus).scheme.upcase} connection")
      payload = { value: 'shutdown' }

      if Bosh::Agent::Config.configure
        # We should never come back up again
        at_exit { `sv stop agent` }
      end

      publish(reply_to, payload) {
        shutdown
      }
    end

    def lookup_encryption_handler(arg)
      if arg[:session_id]
        message_session_id = arg[:session_id]
        @sessions[message_session_id] ||= Bosh::Core::EncryptionHandler.new(@agent_id, @credentials)
        encryption_handler = @sessions[message_session_id]
        return encryption_handler
      elsif arg[:reply_to]
        reply_to = arg[:reply_to]
        @session_reply_map[reply_to]
      end
    end

    def decrypt(msg)
      %w(session_id encrypted_data).each do |key|
        unless msg.key?(key)
          @logger.info("Missing #{key} in #{msg}")
          return
        end
      end

      message_session_id = msg['session_id']
      reply_to = msg['reply_to']

      encryption_handler = lookup_encryption_handler(session_id: message_session_id)

      # save message handler for the reply
      @session_reply_map[reply_to] = encryption_handler

      # Log exceptions from the EncryptionHandler, but stay quiet on the wire.
      begin
        msg = encryption_handler.decrypt(msg['encrypted_data'])
      rescue Bosh::Core::EncryptionHandler::CryptError => e
        log_encryption_error(e)
        return
      end

      msg['reply_to'] = reply_to

      @logger.info("Decrypted Message: #{msg}")
      msg
    end

    def log_encryption_error(e)
      @logger.info("Encrypton Error: #{e.inspect} #{e.backtrace.join('\n')}")
    end

    def encrypt(reply_to, payload)
      encryption_handler = lookup_encryption_handler(reply_to: reply_to)
      session_id = encryption_handler.session_id

      payload = {
        'session_id' => session_id,
        'encrypted_data' => encryption_handler.encrypt(payload)
      }

      payload
    end

    def current_long_running_task?(agent_task_id)
      current_long_running_task[:task_id] == agent_task_id
    end

  end

  # Built-in message handlers
  module Message

    class Ping
      def self.process(args)
        'pong'
      end
    end

    class Noop
      def self.process(args)
        'nope'
      end
    end

    class Start
      def self.process(args)

        if Config.configure
          Bosh::Agent::Monit.start_services
        end

        'started'

      rescue => e
        raise Bosh::Agent::MessageHandlerError, "Cannot start job: #{e}"
      end
    end

    # FIXME: temporary stop method
    class Stop
      def self.long_running?
        true
      end

      def self.process(args)

        if Config.configure
          Bosh::Agent::Monit.stop_services
        end

        'stopped'

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
