module VCloudSdk

  class Config
    class << self
      attr_accessor :logger
      attr_accessor :rest_logger
      attr_accessor :rest_throttle

      def configure(config)
        @logger = config["logger"] || @logger || Logger.new(STDOUT)
        @rest_logger = config["rest_logger"] || @logger
        @rest_throttle = config["rest_throttle"]
      end
    end
  end

end
