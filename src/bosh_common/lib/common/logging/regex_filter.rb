require 'logging/filter'

module Bosh::Common::Logging
  class RegexFilter < ::Logging::Filter
    def initialize(blacklist)
      @blacklist = blacklist
    end

    def allow(event)
      @blacklist.each  do |block|
        return if block.match(event.data)
      end
      event
    end
  end
end
