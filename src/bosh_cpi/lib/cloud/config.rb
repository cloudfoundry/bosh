require 'forwardable'

module Bosh::Clouds
  class Config

    class << self
      extend Forwardable
      def_delegators :@delegate, :db, :logger, :uuid, :uuid=, :task_checkpoint, :cpi_task_log
    end

    # @param [Bosh::Director::Config] config director config file
    def self.configure(config)
      @delegate = config
    end

  end
end
