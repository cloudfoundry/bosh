module VCloudCloud
  class Config
    class << self

      attr_accessor :logger
      attr_accessor :rest_logger
      attr_accessor :rest_throttle

      def configure(config)
        @logger = config['logger'] || Logger.new(STDOUT)
        @rest_logger = config['rest_logger'] || Logger.new(STDOUT)
        @rest_throttle = config['rest_throttle']
      end

    end
  end
end
