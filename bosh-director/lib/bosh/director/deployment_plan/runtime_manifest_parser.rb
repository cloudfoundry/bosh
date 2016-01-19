module Bosh::Director
  module DeploymentPlan
    class RuntimeManifestParser
      include ValidationHelper

      def initialize(logger, deployment=nil)
        @deployment = deployment
        @logger = logger
      end

      def parse(runtime_manifest)
        parse_releases(runtime_manifest)
        parse_addons(runtime_manifest)
      end

      private

      def parse_releases(runtime_manifest)
        @release_specs = []

        if runtime_manifest['release']
          if runtime_manifest['releases']
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

          if @deployment
            deployment_release = @deployment.release(release_spec["name"])
            if deployment_release
              if deployment_release.version != release_spec["version"]
                raise RuntimeInvalidDeploymentRelease, "Runtime manifest specifies release `#{release_spec["name"]}' with version as `#{release_spec["version"]}'. " +
                      "This conflicts with version `#{deployment_release.version}' specified in the deployment manifest."
              else
                next
              end
            end

            release_version = DeploymentPlan::ReleaseVersion.new(@deployment.model, release_spec)
            release_version.bind_model

            @deployment.add_release(release_version)
          end
        end
      end

      def parse_addons(runtime_manifest)
        addons = safe_property(runtime_manifest, 'addons', :class => Array, :default => [])
        addons.each do |addon_spec|
          deployment_plan_templates = []

          addon_jobs = safe_property(addon_spec, 'jobs', :class => Array, :default => [])
          addon_jobs.each do |job|
            if !@release_specs.find { |release_spec| release_spec['name'] == job['release'] }
              raise RuntimeReleaseNotListedInReleases,
                    "Runtime manifest specifies job `#{job['name']}' which is defined in `#{job['release']}', but `#{job['release']}' is not listed in the releases section."
            end

            if @deployment
              template_object = DeploymentPlan::Template.new(@deployment.release(job['release']), job['name'])
              template_object.bind_models

              deployment_plan_templates.push(template_object)
            end
          end

          if @deployment
            @deployment.jobs.each do |job|
              merge_addon(job, deployment_plan_templates, addon_spec['properties'])
            end
          end
        end
      end

      def merge_addon(job, templates, properties)
        puts "merging job: #{job} with templates: #{templates} and properties: #{properties}"
        if job.templates
          job.templates.concat(templates)
        else
          job.templates = templates
        end

        if properties
          if job.all_properties
            job.all_properties.merge!(properties)
          else
            job.all_properties = properties
          end
        end
      end
    end
  end
end
