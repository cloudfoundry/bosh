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
      puts "An exception occurred running #{example.location}:"
      puts "\tTest directory:     #{tmp_dir}"
      puts "\tSandbox directory:  #{Bosh::Dev::Sandbox::Workspace.dir}"
      puts "\t#{example.exception.inspect}\n"
    else
      FileUtils.rm_rf(tmp_dir) unless tmp_dir.nil?
    end
  end
end
