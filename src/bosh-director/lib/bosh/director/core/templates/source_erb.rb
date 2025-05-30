require 'bosh/director/core/templates'
require 'bosh/common/template/evaluation_context'

module Bosh::Director::Core::Templates
  class SourceErb
    @@mutex = Mutex.new

    attr_reader :src_filepath, :dest_filepath, :erb

    def initialize(src_filepath, dest_filepath, erb_contents, job_name)
      @src_filepath = src_filepath
      @dest_filepath = dest_filepath
      erb = ERB.new(erb_contents, trim_mode: "-")
      erb.filename = File.join(job_name, src_filepath)
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

      message = "Error filling in template '#{@src_filepath}' (line #{line}: #{e})"

      logger.debug("#{message}\n#{e.backtrace.join("\n")}")
      raise message
    end
  end
end
