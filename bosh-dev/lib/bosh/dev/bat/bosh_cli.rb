require 'bosh/dev/bat'
require 'bosh/dev/bat/shell'

module Bosh::Dev::Bat
  class BoshCli
    def initialize
      @shell = Shell.new
    end

    def run_bosh(cmd, options = {})
      debug_on_fail = !!options.delete(:debug_on_fail)

      puts "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}"
      shell.run "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}", options
    rescue
      run_bosh 'task last --debug', last_number: 100, debug_on_fail: false if debug_on_fail
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
