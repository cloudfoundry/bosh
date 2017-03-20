module Bosh::Director
  module RuntimeConfig
    class RuntimeManifestParser
      include ValidationHelper

      def parse(runtime_manifest)
        runtime_config_releases = parse_releases(runtime_manifest)
        parsed_addons = parse_addons(runtime_config_releases, runtime_manifest)
        ParsedRuntimeConfig.new(runtime_config_releases, parsed_addons)
      end

      private

      def parse_releases(runtime_manifest)
        safe_property(runtime_manifest, 'releases', :class => Array).inject([]) do |releases, release_hash|
          releases << RuntimeConfig::Release.parse(release_hash)
        end
      end

      def parse_addons(runtime_config_releases, runtime_manifest)
        Addon::Parser.new(runtime_config_releases,runtime_manifest).parse
      end
    end
  end
end
