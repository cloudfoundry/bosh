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
        @links_parser = Bosh::Director::Links::LinksParser.new
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

          #TODO LINKS: Make same changes as in instance_group_spec_parser
          deployment.instance_groups.map(&:name).each do |instance_group_name|
            if addon_job_hash['properties']
              job_properties = addon_job_hash['properties']
            else
              job_properties = @addon_level_properties
            end

            addon_job_object.add_properties(job_properties, instance_group_name)

            @links_parser.parse_providers_from_job(addon_job_hash, deployment.model, addon_job_object.model, job_properties, instance_group_name)
            @links_parser.parse_consumers_from_job(addon_job_hash, deployment.model, addon_job_object.model, instance_group_name)
          end
          jobs << addon_job_object
        end
        jobs
      end
    end
  end
end
