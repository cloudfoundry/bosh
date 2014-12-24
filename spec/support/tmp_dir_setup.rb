require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'bosh/dev/sandbox/debug_logs'

RSpec.configure do |config|
  BASE_TMP_DIR = File.join(Bosh::Dev::Sandbox::DebugLogs.log_directory, "pid-#{Process.pid}")
  FileUtils.rm_rf(BASE_TMP_DIR)
  FileUtils.mkdir_p(BASE_TMP_DIR)

  config.after do |example|
    if example.exception
      example.exception.message << "\nTest directory: #{BASE_TMP_DIR}"
    end
  end
end
