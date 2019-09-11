require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'bosh/dev/sandbox/workspace'

RSpec.configure do |config|
  tmp_dir = nil

  config.before do
    FileUtils.mkdir_p(Bosh::Dev::Sandbox::Workspace.dir)
    tmp_dir = Dir.mktmpdir('spec-', Bosh::Dev::Sandbox::Workspace.dir)

    allow(Dir).to receive(:tmpdir).and_return(tmp_dir)
  end

  config.after do |example|
    if example.exception
      puts "An exception occurred running #{example.class.name}:"
      puts example.exception.inspect.to_s
      puts "\nTest directory: #{tmp_dir}"
      puts "\nSandbox directory: #{Bosh::Dev::Sandbox::Workspace.dir}"
    else
      FileUtils.rm_rf(tmp_dir)
    end
  end
end
