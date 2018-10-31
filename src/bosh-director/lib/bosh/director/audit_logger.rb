require 'logging'
require 'singleton'

module Bosh::Director
  class AuditLogger
    include Singleton

    def initialize
      @logger = Logging::Logger.new('DirectorAudit')
      @logger.level = 'debug'
      @logger.add_appenders(
        Logging.appenders.file(
          'DirectorAudit',
          filename: File.join(Config.audit_log_path, Config.audit_filename),
          layout: ThreadFormatter.layout,
        ),
      )
    end

    def info(message)
      @logger.info(message)
    end
  end
end
