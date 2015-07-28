module Bosh::Director
  class TaggedLogger
    def initialize(logger, *tags)
      @logger = logger
      @tags = tags.map { |t| "[#{t}]" }.join('')
    end

    def error(message)
      @logger.error(tag_message(message))
    end

    def info(message)
      @logger.info(tag_message(message))
    end

    def debug(message)
      @logger.debug(tag_message(message))
    end

    def warn(message)
      @logger.warn(tag_message(message))
    end

    private

    def tag_message(message)
      "#{@tags} #{message}"
    end
  end
end
