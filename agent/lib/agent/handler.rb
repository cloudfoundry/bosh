
module Bosh::Agent

  class MessageHandlerError < StandardError; end
  class UnknownMessage < StandardError; end
  class LoadSettingsError < StandardError; end

  class Handler
    attr_reader :processors

    class << self
      def start
        Handler.new.start
      end
    end

    def initialize
      @agent_id = Config.agent_id
      @logger = Config.logger
      @nats_uri = Config.mbus
      @base_dir = Config.base_dir

      @lock = Mutex.new
      @long_running_agent_task = []
      @results = []
      message_processors
    end

    # TODO: add runtime loading of messag handlers
    def message_processors
      message_consts = Bosh::Agent::Message.constants
      @processors = {}
      message_consts.each do |c|
        klazz = Bosh::Agent::Message.const_get(c)
        if klazz.respond_to?(:process)
          # CamelCase -> under_score -> downcased
          processor_key = c.gsub(/(.)([A-Z])/,'\1_\2').downcase
          @processors[processor_key] = klazz
        end
      end
      @logger.info("Message processors: #{@processors.inspect}")
    end

    # TODO:
    def lookup(method)
      @processors[method]
    end

    def start
      begin
        NATS.start do
          @nats = NATS.connect(:uri => @nats_uri, :autostart => false) { on_connect }
        end
      rescue Errno::ENETUNREACH, Timeout::Error => e
        @logger.info("Unable to talk to nats - retry (#{e.inspect})")
        sleep 0.1
        retry
      end
    end

    def on_connect
      subscription = "agent.#{@agent_id}"
      @nats.subscribe(subscription) { |raw_msg| handle_message(raw_msg) }
    end

    def handle_message(msg_raw)
      msg = Yajl::Parser.new.parse(raw_msg)

      @logger.info("Message: #{msg.inspect}")

      reply_to = msg['reply_to']
      method = msg['method']
      args = msg['arguments']

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
            publish(reply_to, payload)
            if Config.configure && method == "prepare_network_change"
              post_prepare_network_change
            end
          end
        }
      elsif method == "get_task"
        handle_get_task(reply_to, args.first)
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

    def publish(reply_to, payload)
      @nats.publish(reply_to, Yajl::Encoder.encode(payload))
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
        return {:exception => e.inspect}
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
        settings_file = File.join(@base_dir, 'bosh', 'settings.json')
        `rm #{settings_file}`
      end

      @logger.info("Halt after networking change")
      `/sbin/halt`
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

    # FIXME: temporary stop method
    class Stop
      def self.process(args)
        `monit -g #{BOSH_APP_GROUP} stop`
        "stopped"
      end
    end

    class PrepareNetworkChange
      def self.process(args)
        true
      end
    end

  end

end
