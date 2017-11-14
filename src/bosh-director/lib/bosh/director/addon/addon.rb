module Bosh::Director
  module Addon
    DEPLOYMENT_LEVEL = :deployment
    RUNTIME_LEVEL = :runtime

    class Addon
      extend ValidationHelper

      attr_reader :name

      def initialize(name, job_hashes, addon_level_properties, addon_include, addon_exclude)
        @name = name
        @addon_job_hashes = job_hashes
        @addon_level_properties = addon_level_properties
        @addon_include = addon_include
        @addon_exclude = addon_exclude
      end

      def jobs
        @addon_job_hashes
      end

      def properties
        @addon_level_properties
      end

      def self.parse(addon_hash, addon_level = RUNTIME_LEVEL)
        name = safe_property(addon_hash, 'name', :class => String)
        addon_job_hashes = safe_property(addon_hash, 'jobs', :class => Array, :default => [])
        parsed_addon_jobs = []
        addon_job_hashes.each do |addon_job_hash|
          parsed_addon_jobs << parse_and_validate_job(addon_job_hash)
        end
        addon_level_properties = safe_property(addon_hash, 'properties', class: Hash, optional: true)
        addon_include = Filter.parse(safe_property(addon_hash, 'include', :class => Hash, :optional => true), :include, addon_level)
        addon_exclude = Filter.parse(safe_property(addon_hash, 'exclude', :class => Hash, :optional => true), :exclude, addon_level)

        new(name, parsed_addon_jobs, addon_level_properties, addon_include, addon_exclude)
      end

      def applies?(deployment_name, deployment_teams, deployment_instance_group)
        @addon_include.applies?(deployment_name, deployment_teams, deployment_instance_group) && !@addon_exclude.applies?(deployment_name, deployment_teams, deployment_instance_group)
      end

      def add_to_deployment(deployment)
        jobs = convert_addon_jobs_to_object(deployment)
        deployment.instance_groups.each do |instance_group|
          if applies?(deployment.name, deployment.team_names, instance_group)
            add_jobs_to_instance_group(instance_group, jobs)
          end
        end
      end

      private

      def self.parse_and_validate_job(addon_job)
        {
          'name' => safe_property(addon_job, 'name', :class => String),
          'release' => safe_property(addon_job, 'release', :class => String),
          'provides_links' => safe_property(addon_job, 'provides', class: Hash, default: {}).to_a,
          'consumes_links' => safe_property(addon_job, 'consumes', class: Hash, default: {}).to_a,
          'properties' => safe_property(addon_job, 'properties', class: Hash, optional: true),
        }
      end

      def add_jobs_to_instance_group(instance_group, jobs)
        jobs.each { |job| instance_group.add_job(job) }
      end

      def convert_addon_jobs_to_object(deployment)
        jobs = []
        @addon_job_hashes.each do |addon_job_hash|
          deployment_release_version = deployment.release(addon_job_hash['release'])
          deployment_release_version.bind_model

          addon_job_object = DeploymentPlan::Job.new(deployment_release_version, addon_job_hash['name'], deployment.name)
          addon_job_object.bind_models

          deployment.instance_groups.map(&:name).each do |instance_group_name|
            add_link_from_release(addon_job_object, instance_group_name)

            add_links_from_manifest(addon_job_object, addon_job_hash, instance_group_name)

            add_properties(addon_job_hash, addon_job_object, instance_group_name)
          end
          jobs << addon_job_object
        end
        jobs
      end

      def add_properties(addon_job_hash, addon_job_object, instance_group_name)
        if addon_job_hash['properties']
          addon_job_object.add_properties(addon_job_hash['properties'], instance_group_name)
        else
          addon_job_object.add_properties(@addon_level_properties, instance_group_name)
        end
      end

      def add_link_from_release(addon_job_object, instance_group_name)
        addon_template_model = addon_job_object.model

        addon_template_model.consumes.to_a.each do |deployment_job_consumes|
          addon_job_object.add_link_from_release(instance_group_name, 'consumes', deployment_job_consumes['name'], deployment_job_consumes)
        end

        addon_template_model.provides.to_a.each do |deployment_job_provides|
          addon_job_object.add_link_from_release(instance_group_name, 'provides', deployment_job_provides['name'], deployment_job_provides)
        end
      end

      def add_links_from_manifest(addon_job_object, addon_job_hash, instance_group_name)
        addon_job_hash['provides_links'].each do |link_name, source|
          addon_job_object.add_link_from_manifest(instance_group_name, 'provides', link_name, source)
        end

        addon_job_hash['consumes_links'].each do |link_name, source|
          addon_job_object.add_link_from_manifest(instance_group_name, 'consumes', link_name, source)
        end
      end
    end
  end
end
