require 'bosh/dev'
require 'bosh/core/shell'
require 'common/retryable'
require 'tempfile'

module Bosh::Dev
  class BoshCliSession
    def initialize
      @shell = Bosh::Core::Shell.new
    end

    def run_bosh(cmd, options = {})
      debug_on_fail = !!options.delete(:debug_on_fail)
      retryable     = options.delete(:retryable) || Bosh::Retryable.new

      bosh_command = "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}"
      puts bosh_command
      retryable.retryer { shell.run(bosh_command, options) }
    rescue RuntimeError
      run_bosh('task last --debug', last_number: 100, debug_on_fail: false) if debug_on_fail
      raise
    end

    private

    attr_reader :shell

    def bosh_config_path
      # We should keep a reference to the tempfile, otherwise,
      # when the object gets GC'd, the tempfile is deleted.
      @bosh_config_tempfile ||= Tempfile.new('bosh_config')
      @bosh_config_tempfile.path
    end
  end
end
