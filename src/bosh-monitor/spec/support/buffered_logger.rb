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
end

RSpec.configure do |c|
  c.include(BufferedLogger)

  c.before do
    @test_log_buffer = StringIO.new
    @test_logger = Logging.logger(@test_log_buffer)
    @test_stdlib_logger = Logger.new(@test_log_buffer)
    allow(Logging).to receive(:logger).and_return(@test_logger)
    allow(Logger).to receive(:new).and_return(@test_stdlib_logger)
  end

  c.after do |example|
    # Print logs if the test failed
    unless example.exception.nil?
      STDERR.write("\nTest Failed: '#{example.full_description}'\nTest Logs:\n#{@test_log_buffer.string}\n")
    end
  end
end
