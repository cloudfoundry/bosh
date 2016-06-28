module Bosh::Director
  module DeploymentPlan
    class RuntimeManifestParser
      include ValidationHelper

      attr_reader :release_specs
      attr_reader :addons
      attr_reader :include_spec

      def initialize
        @release_specs = []
        @addons = []
        @include_spec = nil
      end

      def parse(runtime_manifest)
        parse_releases(runtime_manifest)
        addons = safe_property(runtime_manifest, 'addons', :class => Array, :default => [])
        parse_addons(addons)
        parse_addons_include_section(addons)
      end

      private

      def parse_releases(runtime_manifest)
        if runtime_manifest['release']
          if runtime_manifest['releases']
            raise RuntimeAmbiguousReleaseSpec,
                  "Runtime manifest contains both 'release' and 'releases' " +
                      'sections, please use one of the two.'
          end
          @release_specs << runtime_manifest['release']
        else
          safe_property(runtime_manifest, 'releases', :class => Array).each do |release|
            @release_specs << release
          end
        end

        @release_specs.each do |release_spec|
          if release_spec['version'] =~ /(^|[\._])latest$/
            raise RuntimeInvalidReleaseVersion,
                  "Runtime manifest contains the release '#{release_spec['name']}' with version as '#{release_spec['version']}'. " +
                      "Please specify the actual version string."
          end
        end
      end

      def parse_addons(addons)
        addons.each do |addon|
          parsed_addon = { 'name' => safe_property(addon, 'name', :class => String) }

          addon_jobs = safe_property(addon, 'jobs', :class => Array, :default => [])
          parsed_jobs = []
          addon_jobs.each do |addon_job|
            parsed_job = { 'name' => safe_property(addon_job, 'name', :class => String),
                           'release' => safe_property(addon_job, 'release', :class => String) }

            if !@release_specs.find { |release_spec| release_spec['name'] == parsed_job['release'] }
              raise RuntimeReleaseNotListedInReleases,
                    "Runtime manifest specifies job '#{parsed_job['name']}' which is defined in '#{parsed_job['release']}', but '#{parsed_job['release']}' is not listed in the releases section."
            end

            parsed_job['provides_links'] = safe_property(addon_job, 'provides', class: Hash, default: {}).to_a
            parsed_job['consumes_links'] = safe_property(addon_job, 'consumes', class: Hash, default: {}).to_a
            parsed_job['properties'] = safe_property(addon_job, 'properties', class: Hash, default: nil)
            parsed_jobs.push(parsed_job)
          end
          parsed_addon['jobs'] = parsed_jobs
          parsed_addon['properties'] = safe_property(addon, 'properties', class: Hash, default: nil)
          @addons.push(parsed_addon)
        end
      end

      def parse_addons_include_section(addons)
        include_map = {}
        addons.each do |addon|
          if (addon_include = safe_property(addon, 'include', :class => Hash, :optional => true))
            addon_include_in_deployments = safe_property(addon_include, 'deployments', :class => Array, :default => [])
            addon_include_in_jobs = safe_property(addon_include, 'jobs', :class => Array, :default => [])

            #TODO throw an exception with all wrong jobs
            verify_jobs_section(addon_include_in_jobs)

            include_map[addon['name']] = { 'jobs' => addon_include_in_jobs,
                                            'deployments' => addon_include_in_deployments }
          end
        end
        @include_spec = RuntimeInclude.new(include_map)
      end

      def verify_jobs_section(addon_include_in_jobs)
        addon_include_in_jobs.each do |job|
          name = safe_property(job, 'name', :class => String, :default => '')
          release = safe_property(job, 'release', :class => String, :default => '')
          if name.empty? || release.empty?
            raise RuntimeIncompleteIncludeJobSection.new("Job #{job} in runtime config's include section must" +
                                                             "have both name and release.")
          end
        end
      end
    end
  end
end
