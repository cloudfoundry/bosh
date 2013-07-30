require 'bosh/dev/bat'
require 'bosh/dev/bat/shell'

module Bosh::Dev::Bat
  class BoshCli
    def initialize
      @shell = Shell.new
    end

    def run_bosh(cmd, options = {})
      debug_on_fail = options.fetch(:debug_on_fail, false)
      options.delete(:debug_on_fail)
      @run_bosh_failures ||= 0
      puts "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}"
      shell.run "bosh -v -n -P 10 --config '#{bosh_config_path}' #{cmd}", options
    rescue
      @run_bosh_failures += 1
      if @run_bosh_failures == 1 && debug_on_fail
        # get the debug log, but only for the first failure, in case "bosh task last"
        # fails - or we'll end up in an endless loop
        run_bosh 'task last --debug', last_number: 100
        @run_bosh_failures = 0
      end
      raise
    end

    def bosh_config_path
      # We should keep a reference to the tempfile, otherwise,
      # when the object gets GC'd, the tempfile is deleted.
      @bosh_config_tempfile ||= Tempfile.new('bosh_config')
      @bosh_config_tempfile.path
    end

    private

    attr_reader :shell
  end
end
