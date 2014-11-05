require 'rspec'
require 'logger'
require 'mono_logger'

# returns the log as a string
def log_string
  @test_log_buffer.string
end

def logger
  @test_logger
end

RSpec.configure do |c|
  c.before do
    @test_log_buffer = StringIO.new
    @test_logger = MonoLogger.new(@test_log_buffer)
    allow(MonoLogger).to receive(:new).and_return(@test_logger)
    allow(Logger).to receive(:new).and_return(@test_logger)
  end

  c.after do |example|
    # Print logs if the test failed
    unless example.exception.nil?
      STDERR.write("\nTest Failed: '#{example.full_description}'\nTest Logs:\n#{@test_log_buffer.string}\n")
    end
  end
end
