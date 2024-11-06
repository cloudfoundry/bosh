module Bosh::Monitor
  module Plugins
    class Base
      attr_reader :logger
      attr_reader :options
      attr_reader :event_kinds

      def initialize(options = {})
        @logger  = Bosh::Monitor.logger
        @options = (options || {}).dup
        @event_kinds = []
      end

      def validate_options
        true
      end

      def run
        raise FatalError, "'run' method is not implemented in '#{self.class}'"
      end

      def process(_event)
        raise FatalError, "'process' method is not implemented in '#{self.class}'"
      end
    end
  end
end
