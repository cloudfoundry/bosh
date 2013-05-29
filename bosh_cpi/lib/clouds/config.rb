module Bosh::Clouds
  class Config

    class << self
      extend Forwardable
      def_delegators :@delegate, :db, :logger, :uuid, :task_checkpoint
    end

    # @param [Bosh::Director::Config] config director config file
    def self.configure(config)
      @delegate = config
    end

  end
end
