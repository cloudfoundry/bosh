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
          if release_spec['version'] == 'latest'
            raise RuntimeInvalidReleaseVersion,
                  "Runtime manifest contains the release '#{release_spec['name']}' with version as 'latest'. " +
                      "Please specify the actual version string."
          end

          if @deployment
            deployment_release = @deployment.release(release_spec["name"])
            if deployment_release
              if deployment_release.version != release_spec["version"].to_s
                raise RuntimeInvalidDeploymentRelease, "Runtime manifest specifies release '#{release_spec["name"]}' with version as '#{release_spec["version"]}'. " +
                      "This conflicts with version '#{deployment_release.version}' specified in the deployment manifest."
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

          addon_jobs.each do |addon_job|
            if !@release_specs.find { |release_spec| release_spec['name'] == addon_job['release'] }
              raise RuntimeReleaseNotListedInReleases,
                    "Runtime manifest specifies job '#{addon_job['name']}' which is defined in '#{addon_job['release']}', but '#{addon_job['release']}' is not listed in the releases section."
            end

            if @deployment
              valid_release_versions = @deployment.releases.map {|r| r.name }
              deployment_release_ids = Models::Release.where(:name => valid_release_versions).map {|r| r.id}
              deployment_jobs = @deployment.jobs

              templates_from_model = Models::Template.where(:name => addon_job['name'], :release_id => deployment_release_ids)
              if templates_from_model == nil
                raise "Job '#{addon_job['name']}' not found in Template table"
              end

              release = @deployment.release(addon_job['release'])
              release.bind_model

              template = DeploymentPlan::Template.new(release, addon_job['name'])

              deployment_jobs.each do |j|
                templates_from_model.each do |template_from_model|
                  if template_from_model.consumes != nil
                    template_from_model.consumes.each do |consumes|
                      template.add_link_from_release(j.name, 'consumes', consumes["name"], consumes)
                    end
                  end
                  if template_from_model.provides != nil
                    template_from_model.provides.each do |provides|
                      template.add_link_from_release(j.name, 'provides', provides["name"], provides)
                    end
                  end
                end

                provides_links = safe_property(addon_job, 'provides', class: Hash, optional: true)
                provides_links.to_a.each do |link_name, source|
                  template.add_link_from_manifest(j.name, "provides", link_name, source)
                end

                consumes_links = safe_property(addon_job, 'consumes', class: Hash, optional: true)
                consumes_links.to_a.each do |link_name, source|
                  template.add_link_from_manifest(j.name, 'consumes', link_name, source)
                end

                if addon_job.has_key?('properties')
                  template.add_template_scoped_properties(addon_job['properties'], j.name)
                end
              end

              template.bind_models
              deployment_plan_templates.push(template)

              deployment_jobs.each do |job|
                merge_addon(job, deployment_plan_templates, addon_spec['properties'])
              end

            end
          end
        end
      end

      def merge_addon(job, templates, properties)
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
