module Bosh::Director
  module DeploymentPlan
    class RuntimeManifestParser
      include ValidationHelper

      def initialize(logger)
        @logger = logger
      end

      def parse(runtime_manifest)
        parse_releases(runtime_manifest)
        parse_addons(runtime_manifest)
      end

      private

      def parse_releases(runtime_manifest)
        @release_specs = []

        if runtime_manifest.has_key?('release')
          if runtime_manifest.has_key?('releases')
            raise RuntimeAmbiguousReleaseSpec,
                  "Runtime manifest contains both `release' and `releases' " +
                      'sections, please use one of the two.'
          end
          @release_specs << runtime_manifest['release']
        else
          safe_property(runtime_manifest, 'releases', :class => Array).each do |release|
            @release_specs << release
          end
        end

        @release_specs.each do |release_spec|
          if release_spec['version'] == 'latest'
            raise RuntimeInvalidReleaseVersion,
                  "Runtime manifest contains the release `#{release_spec['name']}' with version as `latest'. " +
                      "Please specify the actual version string."
          end
        end
      end

      def parse_addons(runtime_manifest)
        addons = safe_property(runtime_manifest, 'addons', :class => Array, :default => [])
        addons.each do |addon_spec|
          jobs = safe_property(addon_spec, 'jobs', :class => Array, :default => [])
          jobs.each do |job|
            if !@release_specs.find { |release_spec| release_spec['name'] == job['release'] }
              raise RuntimeReleaseNotListedInReleases,
                    "Runtime manifest specifies job `#{job['name']}' which is defined in `#{job['release']}', but `#{job['release']}' is not listed in the releases section."
            end
          end
        end
      end
    end
  end
end
