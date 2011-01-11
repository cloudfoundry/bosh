
module Bosh::Agent

  class MessageHandlerError < StandardError; end
  class UnknownMessage < StandardError; end

  class Handler
    attr_reader :processors

    class << self
      def start
        Handler.new.start
      end
    end

    def initialize
      redis_config = Config.redis_options
      @pubsub_redis = Redis.new(redis_config)
      @redis = Redis.new(redis_config)
      @agent_id = Config.agent_id
      @logger = Config.logger

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

    def start
      # FIXME: terminate gracefully by unsubscribing before exit
      # TODO: deal with signals
      trap("TERM") { "Shutting down agent" ; exit }

      subscription = "rpc:agent:#{@agent_id}"

      @pubsub_redis.subscribe(subscription) do |on|
        on.subscribe do |sub, msg|
          @logger.info("Subscribed to #{subscription}")
        end
        on.message do |sub, raw_msg|
          msg = Yajl::Parser.new.parse(raw_msg)

          @logger.info("Message: #{msg.inspect}")
          message_id = msg['message_id']
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
                  process_long_running(message_id, processor, args)
                else
                  payload = {:exception => "already running long running task"}
                  publish(message_id, payload)
                end
              else
                payload = process(processor, args)
                publish(message_id, payload)
                if Config.configure && method == "prepare_network_change"
                  while `vmware-rpctool "info-get guestinfo.bosh"`.strip == "nada"
                    sleep 0.1
                  end
                  exit
                end
              end
            }
          elsif method == "get_task"
            handle_get_task(message_id, args.first)
          else
            payload = {:exception => "unknown message #{msg.inspect}"}
            publish(message_id, payload)
          end

        end
        on.unsubscribe do |sub, msg|
          puts "unsubscribing"
        end
      end
    end

    # TODO:
    def lookup(method)
      @processors[method]
    end

    def generate_agent_task_id
      UUIDTools::UUID.random_create.to_s
    end

    def handle_get_task(message_id, agent_task_id)
      if @long_running_agent_task == [agent_task_id]
        publish(message_id, {"value" => {"state" => "running", "agent_task_id" => agent_task_id}})
      else
        rs = @results.find { |time, task_id, result| task_id == agent_task_id }
        if rs
          time, task_id, result = rs
          publish(message_id, result)
        else
          publish(message_id, {"exception" => "unknown agent_task_id" })
        end
      end
    end

    def publish(message_id, payload)
      @redis.publish(message_id, Yajl::Encoder.encode(payload))
    end

    def process_long_running(message_id, processor, args)
      agent_task_id = generate_agent_task_id

      @lock.synchronize do
        @long_running_agent_task = [agent_task_id]
      end

      payload = {:value => {:state => "running", :agent_task_id => agent_task_id}}
      publish(message_id, payload)

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

    # FIXME: temporary drain method
    class Drain
      def self.process(args)
        2
      end
    end

    # FIXME: temporary stop method
    class Stop
      def self.process(args)
        "stopped"
      end
    end

    class UpdatePersistentDisk
      def self.process(args)
        true
      end
    end

    class PrepareNetworkChange
      def self.process(args)
        logger = Bosh::Agent::Config.logger

        `vmware-rpctool "info-set guestinfo.bosh nada"`
        read_back_value = `vmware-rpctool "info-get guestinfo.bosh`
        logger.info('Setting guestinfo.bosh: #{read_back_value}')

        udev_file = '/etc/udev/rules.d/70-persistent-net.rules'
        if File.exist?(udev_file)
          `rm #{udev_file}`
        end

        base_dir = Bosh::Agent::Config.base_dir
        settings_file = File.join(base_dir, 'bosh', 'settings.json')
        settings = Yajl::Parser.new.parse(File.read(settings_file))

        networks = args.first
        settings['networks'] = networks

        File.open(settings_file, 'w') do |f|
          f.puts(Yajl::Encoder.encode(settings))
        end

        true
      end
    end

  end

end
