module Bosh::Director::Links
  class LinksManagerFactory

    # @param logger Logger
    # @return LinksManagerFactory
    def self.create(links_serial_id)
      new(Bosh::Director::Config.logger, Bosh::Director::Config.event_log, links_serial_id)
    end

    # @param logger Logger
    def initialize(logger, event_logger, links_serial_id)
      @logger = logger
      @event_logger = event_logger
      @serial_id = links_serial_id
    end

    # @return LinksManager
    def create_manager
      LinksManager.new(@logger, @event_logger, @serial_id)
    end
  end
end
