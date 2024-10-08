require 'logger'
require 'logging'

module BufferedLogger
  # returns the log as a string
  def log_string
    @test_log_buffer.string
  end

  def logger
    @test_logger
  end

  def logger=(logger)
    puts "ADDING LAGER #{logger.inspect}"
    @test_logger = logger
  end

  def track_logger(name, logger, buffer)
    @test_loggers ||= {}
    @test_loggers[name] = { logger: logger, buffer: buffer }
  end

  def tracked_loggers
    @test_loggers ||= {}
  end

  def tracked_logger(name)
    @test_loggers[name][:logger]
  end
end

RSpec.configure do |c|
  c.include(BufferedLogger)

  c.before do
    # wipe out cached loggers before each test
    Logging::Repository.reset

    # expect all logging to be done with named loggers
    allow(Logger).to receive(:new).and_raise('Do not use Logger.new - Use Logging::Logger')
    allow(Logging).to receive(:logger).and_raise('Do not use Logging.logger - Use Logging::Logger')

    @test_logger = Logging::Logger.new('TestLogger')
    @test_log_buffer = StringIO.new
    @test_logger.add_appenders(Logging.appenders.io('TestLogBuffer', @test_log_buffer))

    logger_new = Logging::Logger.method(:new)
    allow(Logging::Logger).to receive(:new) do |name|
      logger_info = tracked_loggers[name]
      if logger_info
        logger = logger_info[:logger]
      else
        buffer = StringIO.new
        logger = logger_new.call(name)
        logger.add_appenders(Logging.appenders.io("TestLoggerBuffer-#{name}", buffer))
        track_logger(name, logger, buffer)
      end
      logger
    end
  end

  c.after do |example|
    # Print logs if the test failed
    unless example.exception.nil?
      STDERR.write("\nTest Failed: '#{example.full_description}'\n")
      tracked_loggers.each do |name, info|
        STDERR.write("Test Logs (#{name}):\n#{info[:buffer].string}\n")
      end
    end
  end
end
