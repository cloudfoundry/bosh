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
        raw_addons = safe_property(runtime_manifest, 'addons', :class => Array, :default => [])
        raw_addons.inject([]) do |parsed_addons, addon_hash|
          parsed_addon = Addon.parse(addon_hash)
          validate(parsed_addon, runtime_config_releases)
          parsed_addons << parsed_addon
        end
      end

      def validate(addon, runtime_config_releases)
        addon.jobs.each do |addon_job|
          if release_not_listed_in_release_spec(runtime_config_releases, addon_job)
            raise RuntimeReleaseNotListedInReleases,
              "Runtime manifest specifies job '#{addon_job['name']}' which is defined in '#{addon_job['release']}', but '#{addon_job['release']}' is not listed in the releases section."
          end
        end
      end

      def release_not_listed_in_release_spec(runtime_config_releases, parsed_job)
        runtime_config_releases.find { |runtime_config_release| runtime_config_release.name == parsed_job['release'] }.nil?
      end
    end
  end
end
