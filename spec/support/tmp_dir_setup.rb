require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'bosh/dev/sandbox/debug_logs'

RSpec.configure do |config|
  config.before do
    FileUtils.mkdir_p(Bosh::Dev::Sandbox::DebugLogs.logs_dir)
    tmp_dir = Dir.mktmpdir('spec-', Bosh::Dev::Sandbox::DebugLogs.logs_dir)

    allow(Dir).to receive(:tmpdir).and_return(tmp_dir)
  end

  config.after do |example|
    if example.exception
      example.exception.message << "\nTest directory: #{Bosh::Dev::Sandbox::DebugLogs.logs_dir}"
    end
  end
end
