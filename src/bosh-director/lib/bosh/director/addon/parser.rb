module Bosh::Director
  module Addon
    class Parser
      include ValidationHelper

      def initialize(releases, manifest, addon_level = RUNTIME_LEVEL)
        @releases = releases
        @manifest = manifest
        @addon_level = addon_level
      end

      def parse
        raw_addons = safe_property(@manifest, 'addons', :class => Array, :default => [])
        raw_addons.inject([]) do |parsed_addons, addon_hash|
          parsed_addon = Bosh::Director::Addon::Addon.parse(addon_hash, @addon_level)
          validate(parsed_addon)
          parsed_addons << parsed_addon
        end
      end

      private

      def validate(addon)
        addon.jobs.each do |addon_job|
          if release_not_listed_in_release_spec(addon_job)
            raise AddonReleaseNotListedInReleases,
              "Manifest specifies job '#{addon_job['name']}' which is defined in '#{addon_job['release']}', but '#{addon_job['release']}' is not listed in the #{@addon_level} releases section."
          end
        end
      end

      def release_not_listed_in_release_spec(parsed_job)
        @releases.find { |release| release.name == parsed_job['release'] }.nil?
      end
    end
  end
end
