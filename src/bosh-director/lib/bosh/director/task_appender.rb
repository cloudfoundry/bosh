module Bosh::Director

  class TaskAppender < ::Logging::Appender
    def initialize(name, opts = {})
      super
      @db_writer = opts.fetch(:db_writer)
    end

    private

    def write(event)
      message = if event.instance_of?(::Logging::LogEvent)
        @layout.format(event)
      else
        event.to_s
      end
      return if message.empty?
      @db_writer.write(message)
      self
    end
  end
end

