require 'bosh/director/core/templates'
require 'bosh/template/evaluation_context'

module Bosh::Director::Core::Templates
  class SourceErb
    @@mutex = Mutex.new

    attr_reader :src_name, :dest_name, :erb

    def initialize(src_name, dest_name, erb_contents, template_name)
      @src_name = src_name
      @dest_name = dest_name
      erb = ERB.new(erb_contents, safe_level = nil, trim_mode = "-")
      erb.filename = File.join(template_name, src_name)
      @erb = erb
    end

    def render(context, logger)
      @@mutex.synchronize do
        erb.result(context.get_binding)
      end
      # rubocop:disable RescueException
    rescue Exception => e
      # rubocop:enable RescueException

      logger.debug(e.inspect)
      line_index = e.backtrace.index { |l| l.include?(erb.filename) }
      line = line_index ? e.backtrace[line_index] : '(unknown):(unknown)'
      template_name, line = line.split(':')

      message = "Error filling in template '#{File.basename(template_name)}' (line #{line}: #{e})"

      logger.debug("#{message}\n#{e.backtrace.join("\n")}")
      raise message
    end
  end
end
