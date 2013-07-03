require "yaml"
require "ruby_vcloud_sdk"


module VCloudSdk
  module Test

    class << self
      def spec_asset(filename)
        File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
      end

      def test_configuration
        @@test_config ||= Psych.load_file(spec_asset("test-config.yml"))
      end

      def properties
        test_configuration["properties"]
      end

      def get_vcd_settings
        vcds = properties["vcds"]
        raise "Invalid number of VCDs" unless vcds.size == 1
        vcds[0]
      end

      def vcd_settings
        @@settings ||= get_vcd_settings
      end

      def generate_unique_name
        SecureRandom.uuid
      end

      def compare_xml(a, b)
        a.diff(b) do |change, node|
          # " " Means no difference.  "+" means addition and "-" means deletion.
          return false if change != " " && node.to_s.strip().length != 0
        end
        true
      end

      def rest_logger(logger)
        rest_log_filename = File.join(File.dirname(
          logger.instance_eval { @logdev }.dev.path), "rest")
        log_file = File.open(rest_log_filename, "w")
        log_file.sync = true
        rest_logger = Logger.new(log_file || STDOUT)
        rest_logger.level = logger.level
        rest_logger.formatter = logger.formatter
        def rest_logger.<<(str)
          self.debug(str.chomp)
        end
        rest_logger
      end
    end

  end

  module Xml

    class Wrapper
      def ==(other)
        @root.diff(other.node) do |change, node|
          # " " Means no difference, "+" means addition and "-" means deletion
          return false if change != " " && node.to_s.strip().length != 0
        end
        true
      end
    end

  end

  class Config
    class << self
      def logger()
        log_file = VCloudSdk::Test::properties["log_file"]
        FileUtils.mkdir_p(File.dirname(log_file))
        logger = Logger.new(log_file)
        logger.level = Logger::DEBUG
        logger
      end
    end
  end

end



module Kernel

  def with_thread_name(name)
    old_name = Thread.current[:name]
    Thread.current[:name] = name
    yield
  ensure
    Thread.current[:name] = old_name
  end

end

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true  # for RSpec-3
  c.filter_run :all

  c.after :all do
    FileUtils.rm_rf(File.dirname(VCloudSdk::Test::properties["log_file"]))
  end
end
