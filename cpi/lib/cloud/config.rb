module Bosh::Clouds
  class Config

    class << self

      attr_accessor :logger, :uuid, :db

      def configure(config = {})
        unless @logger = config["logger"]
          logging = config["logging"] || {}
          @logger = Logger.new(logging["file"] || STDOUT)
          @logger.level = Logger.const_get((logging["level"] || "INFO").upcase)
        end

        @uuid = config["uuid"]
        @db = config["db"]
      end

    end
  end
end

module Kernel

  def with_thread_name(name)
    old_name = Thread.current[:name]
    Thread.current[:name] = name
    yield
  ensure
    Thread.current[:name] = old_name
  end

end
