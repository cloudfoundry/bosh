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
      example.exception.message << "\nTest directory: #{tmp_dir}"
      example.exception.message << "\nSandbox directory: #{Bosh::Dev::Sandbox::Workspace.dir}"
    else
      FileUtils.rm_rf(tmp_dir)
    end
  end
end
