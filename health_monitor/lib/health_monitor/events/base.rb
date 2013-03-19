module Bosh::HealthMonitor
  module Events
    class Base
      attr_accessor :id

      attr_reader :logger
      attr_reader :kind
      attr_reader :attributes
      attr_reader :errors

      def self.create!(kind, attributes = {})
        event = create(kind, attributes)
        if !event.valid?
          raise InvalidEvent, event.error_message
        end
        event
      end

      def self.create(kind, attributes = {})
        if !attributes.kind_of?(Hash)
          raise InvalidEvent, "Cannot create event from #{attributes.class}"
        end

        # TODO: add dynamic register/lookup?
        case kind.to_s
        when "heartbeat"
          klass = Bhm::Events::Heartbeat
        when "alert"
          klass = Bhm::Events::Alert
        else
          raise InvalidEvent, "Cannot find `#{kind}' event handler"
        end

        event = klass.new(attributes)
        event.id = SecureRandom.uuid if event.id.nil?
        event
      end

      def initialize(attributes = {})
        @attributes = {}
        @kind = :unknown

        attributes.each_pair do |k, v|
          @attributes[k.to_s] = v
        end

        @logger = Bhm.logger
        @errors = Set.new
      end

      def add_error(error)
        @errors << error
      end

      def valid?
        validate
        @errors.empty?
      end

      def error_message
        @errors.to_a.join(", ")
      end

      [:validate, :to_plain_text, :to_hash, :to_json, :metrics].each do |method|
        define_method(method) do
          raise FatalError, "`#{method}' is not implemented by #{self.class}"
        end
      end
    end
  end
end
