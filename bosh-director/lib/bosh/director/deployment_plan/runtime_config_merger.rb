module Bosh::Director
  module DeploymentPlan
    class RuntimeConfigMerger

      def initialize(deployment)
        @deployment = deployment
      end

      def add_releases(release_specs)
        release_specs.each do |release_spec|
          deployment_release = @deployment.release(release_spec['name'])
          if deployment_release
            if deployment_release.version != release_spec['version'].to_s
              raise RuntimeInvalidDeploymentRelease, "Runtime manifest specifies release '#{release_spec['name']}' with version as '#{release_spec['version']}'. " +
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

      def merge_addon(addon, instance_groups_to_add_to)
        addon_jobs_to_add = []

        addon['jobs'].each do |addon_job|
          deployment_release_names = @deployment.releases.map(&:name)
          deployment_release_ids = Models::Release.where(:name => deployment_release_names).map(&:id)
          saved_jobs = Models::Template.where(:name => addon_job['name'], :release_id => deployment_release_ids)
          if saved_jobs.empty?
            raise "Job '#{addon_job['name']}' not found in Template table"
          end

          release = @deployment.release(addon_job['release'])
          release.bind_model

          addon_job_object = DeploymentPlan::Template.new(release, addon_job['name'])

          @deployment.instance_groups.each do |instance_group|
            saved_jobs.each do |saved_job|
              if saved_job.consumes != nil
                saved_job.consumes.each do |consumes|
                  addon_job_object.add_link_from_release(instance_group.name, 'consumes', consumes['name'], consumes)
                end
              end
              if saved_job.provides != nil
                saved_job.provides.each do |provides|
                  addon_job_object.add_link_from_release(instance_group.name, 'provides', provides['name'], provides)
                end
              end
            end

            addon_job['provides_links'].each do |link_name, source|
              addon_job_object.add_link_from_manifest(instance_group.name, 'provides', link_name, source)
            end

            addon_job['consumes_links'].each do |link_name, source|
              addon_job_object.add_link_from_manifest(instance_group.name, 'consumes', link_name, source)
            end

            if addon_job['properties']
              addon_job_object.add_template_scoped_properties(addon_job['properties'], instance_group.name)
            end
          end

          addon_job_object.bind_models
          addon_jobs_to_add.push(addon_job_object)
        end

        instance_groups_to_add_to.each do |instance_group|
          merge_addon_jobs(instance_group, addon_jobs_to_add, addon['properties'])
        end
      end

      private

      def merge_addon_jobs(instance_group, addon_jobs, properties)
        instance_group.jobs.each do |job|
          addon_jobs.each do |addon_job|
            if addon_job.name == job.name
              raise "Colocated job '#{addon_job.name}' is already added to the instance group '#{instance_group.name}'."
            end
          end
        end
        instance_group.jobs.concat(addon_jobs)

        if properties
          if instance_group.all_properties
            instance_group.all_properties.merge!(properties)
          else
            instance_group.all_properties = properties
          end
        end
      end
    end
  end
end