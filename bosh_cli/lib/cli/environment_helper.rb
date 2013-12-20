module Bosh::Cli
  module EnvironmentHelper
    def self.tmp_dir
      set_tmp_dir unless ENV['TMPDIR']
      ENV['TMPDIR']
    end

    private
    def self.set_tmp_dir
      tmpdir = Dir.mktmpdir
      at_exit { FileUtils.rm_rf(tmpdir) }
      ENV['TMPDIR'] = tmpdir
    end
  end
end