module Bosh::Director
  module RuntimeConfig
    class RuntimeManifestParser
      include ValidationHelper

      def initialize(logger, variables_parser = nil)
        @logger = logger
        @variable_spec_parser = variables_parser
      end

      def parse(runtime_manifest)
        runtime_config_releases = parse_releases(runtime_manifest)
        parsed_addons = parse_addons(runtime_config_releases, runtime_manifest)
        variables = parse_variables(runtime_manifest)
        ParsedRuntimeConfig.new(runtime_config_releases, parsed_addons, variables)
      end

      private

      def parse_releases(runtime_manifest)
        safe_property(runtime_manifest, 'releases', class: Array, default: []).map do |release_hash|
          RuntimeConfig::Release.parse(release_hash)
        end
      end

      def parse_addons(runtime_config_releases, runtime_manifest)
        Addon::Parser.new(runtime_config_releases, runtime_manifest).parse
      end

      def parse_variables(runtime_manifest)
        @variable_spec_parser&.parse(safe_property(runtime_manifest, 'variables', class: Array, optional: true))
      end
    end
  end
end
