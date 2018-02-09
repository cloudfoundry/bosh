module Bosh::Director::Links
  class LinksManagerFactory

    # @param logger Logger
    # @return LinksManagerFactory
    def self.create
      new(Bosh::Director::Config.logger, Bosh::Director::Config.event_log)
    end

    # @param logger Logger
    def initialize(logger, event_logger)
      @logger = logger
      @event_logger = event_logger
    end

    # @return LinksManager
    def create_manager
      LinksManager.new(@logger, @event_logger)
    end
  end
end
