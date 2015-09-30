require 'spec_helper'

module Support
  class TestConfig
    attr_reader :path

    def initialize(command)
      @path = File.join(Dir.mktmpdir, 'bosh_config')
      command.add_option(:config, @path)
    end

    def load
      Bosh::Cli::Config.new(@path)
    end

    def read
      YAML.load(File.read(@path))
    end

    def clean
      FileUtils.rm_rf(@path)
    end
  end
end
