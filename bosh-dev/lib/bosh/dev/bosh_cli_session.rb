require 'bosh/dev'
require 'bosh/core/shell'
require 'common/retryable'
require 'tempfile'
require 'tmpdir'

module Bosh::Dev
  class BoshCliSession
    def self.default
      new(PathBoshCmd.new)
    end

    def initialize(bosh_cmd)
      @bosh_cmd = bosh_cmd
      @shell = Bosh::Core::Shell.new
    end

    def run_bosh(cmd, options = {})
      debug_on_fail = !!options.delete(:debug_on_fail)
      retryable     = options.delete(:retryable) || Bosh::Retryable.new

      bosh_command = "#{@bosh_cmd.cmd} -v -n -P 10 --config '#{bosh_config_path}' #{cmd}"

      # Print out command that's being run so that we now what CI is doing!
      puts bosh_command

      # Do not pass through unrelated options to the shell
      shell_options = { env: @bosh_cmd.env }
      shell_options[:last_number] = options[:last_number] if options[:last_number]

      retryable.retryer { shell.run(bosh_command, shell_options) }

    rescue RuntimeError
      run_bosh('task last --debug', last_number: 100, debug_on_fail: false) if debug_on_fail
      raise
    end

    def close
      @bosh_cmd.close
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

  class PathBoshCmd
    def cmd
      'bosh'
    end

    def env
      {}
    end

    def close
      # noop
    end
  end

  class S3GemBoshCmd
    def initialize(build_number, logger)
      @build_number = build_number
      @shell = Bosh::Core::Shell.new
      @logger = logger
    end

    def cmd
      install_gems_to_dir
      "#{@gem_home}/bin/bosh"
    end

    def env
      install_gems_to_dir
      { 'GEM_PATH' => '', 'GEM_HOME' => @gem_home }
    end

    def close
      if @tmp_dir
        @logger.info("Removing installed gems for version #{@build_number} from #{@tmp_dir}")
        FileUtils.rm_rf(@tmp_dir)
      end
    end

    private

    def install_gems_to_dir
      return if @tmp_dir

      @tmp_dir = Dir.mktmpdir
      @gem_home = "#{@tmp_dir}/ruby/1.9.1"

      @logger.info("Installing gems for version #{@build_number} to #{@tmp_dir}")

      FileUtils.mkdir_p(@tmp_dir)

      File.open("#{@tmp_dir}/Gemfile", 'w') do |f|
        f.write(<<-GEMFILE)
source "https://bosh-ci-pipeline.s3.amazonaws.com/#{@build_number}/gems"
source "https://rubygems.org"
gem "bosh_cli_plugin_micro", "1.#{@build_number}.0"
GEMFILE
      end

      Bundler.with_clean_env do
        @shell.run(
          "bundle install --no-prune --path #{@tmp_dir}",
          env: { 'BUNDLE_GEMFILE' => "#{@tmp_dir}/Gemfile" },
        )
      end
    end
  end
end
