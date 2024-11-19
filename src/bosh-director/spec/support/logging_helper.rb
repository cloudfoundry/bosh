require 'logger'
require 'logging'

module LoggingHelper
  def setup_per_spec_logger_and_buffer(logger, log_buffer)
    @test_logger = logger
    @test_log_buffer = log_buffer
  end

  def per_spec_log_string
    @test_log_buffer.string
  end

  def per_spec_logger
    @test_logger
  end

  def create_tracked_logger(name, original_logger_new)
    return tracked_logger(name) if tracked_logger(name)

    logger, buffer = logger_and_buffer(name, original_logger_new)

    tracked_loggers[name] = { logger: logger, buffer: buffer }

    logger
  end

  def tracked_loggers
    @tracked_loggers ||= {}
  end

  def tracked_logger(name)
    if (logger_info = tracked_loggers[name])
      logger_info[:logger]
    end
  end

  def logger_and_buffer(name, logger_initializer)
    buffer = StringIO.new

    [
      logger_initializer.call(name).tap do |l|
        l.add_appenders(Logging.appenders.io("TestLoggerBuffer-#{name}", buffer))
      end,
      buffer
    ]
  end
end

RSpec.configure do |c|
  c.include(LoggingHelper)

  c.before do
    Logging::Repository.reset # wipe out cached loggers before each test

    logger_new = Logging::Logger.method(:new)
    setup_per_spec_logger_and_buffer(*logger_and_buffer('TestLogger', logger_new))

    allow(Logging::Logger).to receive(:new) do |name|
      create_tracked_logger(name, logger_new)
    end
  end

  c.after do |example|
    unless example.exception.nil? # Print logs if the test failed
      STDERR.write("Test Failed: '#{example.metadata[:file_path]}:#{example.metadata[:line_number]}'\n")
      tracked_loggers.each do |name, info|
        STDERR.write("\tTest Logs (#{name}):\n#{info[:buffer].string}\n")
      end
    end
  end
end
