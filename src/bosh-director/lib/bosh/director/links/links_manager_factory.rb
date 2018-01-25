module Bosh::Director::Links
  class LinksManagerFactory

    # @param logger Logger
    # @return LinksManagerFactory
    def self.create
      new(Bosh::Director::Config.logger)
    end

    # @param logger Logger
    def initialize(logger)
      @logger = logger
    end

    # @return LinksManager
    def create_manager
      LinksManager.new(@logger)
    end
  end
end
