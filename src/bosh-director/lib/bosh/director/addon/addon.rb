module Bosh::Director
  module Addon
    DEPLOYMENT_LEVEL = :deployment
    RUNTIME_LEVEL = :runtime

    class Addon
      include IpUtil
      extend ValidationHelper

      attr_reader :name

      def initialize(name, job_hashes, addon_include, addon_exclude, addon_level_properties)
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

      def self.parse(addon_hash, addon_level = RUNTIME_LEVEL)
        name = safe_property(addon_hash, 'name', class: String)
        addon_job_hashes = safe_property(addon_hash, 'jobs', class: Array, default: [])
        parsed_addon_jobs = addon_job_hashes.map do |addon_job_hash|
          parse_and_validate_job(addon_job_hash)
        end
        addon_include = Filter.parse(safe_property(addon_hash, 'include', class: Hash, optional: true), :include, addon_level)
        addon_exclude = Filter.parse(safe_property(addon_hash, 'exclude', class: Hash, optional: true), :exclude, addon_level)

        Config.event_log.warn_deprecated("Top level 'properties' in addons are deprecated. Please define 'properties' at the job level.") if addon_hash.key?('properties')
        addon_level_properties = safe_property(addon_hash, 'properties', class: Hash, default: {})

        new(name, parsed_addon_jobs, addon_include, addon_exclude, addon_level_properties)
      end

      def applies?(deployment_name, deployment_teams, deployment_instance_group)
        @addon_include.applies?(deployment_name, deployment_teams, deployment_instance_group) &&
          !@addon_exclude.applies?(deployment_name, deployment_teams, deployment_instance_group)
      end

      def add_to_deployment(deployment)
        eligible_instance_groups = deployment.instance_groups.select do |instance_group|
          applies?(deployment.name, deployment.team_names, instance_group)
        end

        add_addon_jobs_to_instance_groups(deployment, eligible_instance_groups) unless eligible_instance_groups.empty?
      end

      def releases
        @addon_job_hashes.map do |addon|
          addon['release']
        end.uniq
      end

      def self.parse_and_validate_job(addon_job)
        {
          'name' => safe_property(addon_job, 'name', class: String),
          'release' => safe_property(addon_job, 'release', class: String),
          'provides' => safe_property(addon_job, 'provides', class: Hash, default: {}),
          'consumes' => safe_property(addon_job, 'consumes', class: Hash, default: {}),
          'properties' => safe_property(addon_job, 'properties', class: Hash, optional: true),
        }
      end

      private_class_method :parse_and_validate_job

      private

      def add_addon_jobs_to_instance_groups(deployment, eligible_instance_groups)
        @addon_job_hashes.each do |addon_job_hash|
          deployment_release_version = deployment.release(addon_job_hash['release'])
          deployment_release_version.bind_model

          addon_job_object = DeploymentPlan::Job.new(deployment_release_version, addon_job_hash['name'])
          addon_job_object.bind_models

          eligible_instance_groups.each do |instance_group|
            instance_group_name = instance_group.name

            job_properties = addon_job_hash['properties'] || @addon_level_properties

            addon_job_object.add_properties(job_properties, instance_group_name)

            @links_parser.parse_providers_from_job(
              addon_job_hash,
              deployment.model,
              addon_job_object.model,
              job_properties: job_properties,
              instance_group_name: instance_group_name,
            )

            @links_parser.parse_consumers_from_job(
              addon_job_hash, deployment.model, addon_job_object.model, instance_group_name: instance_group_name
            )

            instance_group.add_job(addon_job_object)
          end
        end
      end
    end
  end
end
