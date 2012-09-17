$:.unshift(File.expand_path("..", __FILE__))
$:.unshift(File.join(File.dirname(__FILE__), "."))
$:.unshift(File.join(File.dirname(__FILE__), "../lib/cloud"))
$:.unshift(File.join(File.dirname(__FILE__), "unit"))

require "yaml"
require "vcloud"


module VCloudCloud
  module Test
    class << self
      def spec_asset(filename)
        File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
      end

      def test_configuration
        @@test_config ||= YAML.load_file(spec_asset("test-director-config.yml"))
      end

      def vcd_settings
        @@settings ||= get_vcd_settings
      end

      def director_cloud_properties
        test_configuration["cloud"]["properties"]
      end

      def get_vcd_settings
        vcds = director_cloud_properties["vcds"]
        raise "Invalid number of VCDs" unless vcds.size == 1
        vcds[0]
      end

      def test_deployment_manifest
        @@test_manifest ||=
          YAML.load_file(spec_asset("test-deployment-manifest.yml"))
      end

      def generate_unique_name
        UUIDTools::UUID.random_create.to_s
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

end



module VCloudSdk
  class CloudError < RuntimeError; end

  class VappSuspendedError < CloudError; end
  class VmSuspendedError < CloudError; end
  class VappPoweredOffError < CloudError; end

  class ObjectNotFoundError < CloudError; end

  class DiskNotFoundError < ObjectNotFoundError; end
  class CatalogMediaNotFoundError < ObjectNotFoundError; end

  class ApiError < CloudError; end

  class ApiRequestError < ApiError; end
  class ApiTimeoutError < ApiError; end
end


module VCloudSdk
  class Config
    class << self
      def configure(config)
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
end



module Bosh
  module Clouds
    class Config
      class << self
        def logger()
          logger = Logger.new(VCloudCloud::Test::test_configuration[
            "cloud"]["properties"]["log_file"])
          logger.level = Logger::DEBUG
          logger
        end
      end
    end
  end
end
