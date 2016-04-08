module Bosh::Director
  class DeploymentPlan::MigratedFromJob < Struct.new(:name, :availability_zone); end

  class DeploymentPlan::JobMigrator
    def initialize(deployment_plan, logger)
      @deployment_plan = deployment_plan
      @logger = logger
    end

    def find_existing_instances(desired_job)
      instances = []
      existing_instances = @deployment_plan.instance_models.select { |model| model.job == desired_job.name }
      existing_instances.each do |existing_instance|
        instances << existing_instance
      end

      unless desired_job.migrated_from.to_a.empty?
        migrated_from_instances = all_migrated_from_instances(
          desired_job.migrated_from,
          desired_job
        )

        instances += migrated_from_instances
      end

      instances.uniq
    end

    private

    def all_migrated_from_instances(migrated_from_jobs, desired_job)
      desired_job_name = desired_job.name
      migrated_from_instances = []

      migrated_from_jobs.each do |migrated_from_job|
        existing_job = @deployment_plan.job(migrated_from_job.name)
        if existing_job && existing_job.name != desired_job.name
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate instance group '#{migrated_from_job.name}' to '#{desired_job_name}'. " +
              'A deployment can not migrate an instance group and also specify it. ' +
              "Please remove instance group '#{migrated_from_job.name}'."
        end

        other_jobs = @deployment_plan.jobs.reject { |job| job.name == desired_job_name }

        migrate_to_multiple_jobs = other_jobs.any? do |job|
          job.migrated_from.any? do |other_migrated_from_job|
            other_migrated_from_job.name == migrated_from_job.name
          end
        end

        if migrate_to_multiple_jobs
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate instance group '#{migrated_from_job.name}' to '#{desired_job_name}'. An instance group may be migrated to only one instance group."
        end

        migrated_from_job_instances = []

        @deployment_plan.existing_instances.each do |instance|
          if instance.job == migrated_from_job.name
            if instance.availability_zone.nil? &&
              migrated_from_job.availability_zone.nil?  &&
              desired_job.availability_zones.to_a.compact.any?
              raise DeploymentInvalidMigratedFromJob,
                "Failed to migrate instance group '#{migrated_from_job.name}' to '#{desired_job_name}', availability zone of '#{migrated_from_job.name}' is not specified"
            end

            if !migrated_from_job.availability_zone.nil? && !instance.availability_zone.nil?
              if migrated_from_job.availability_zone != instance.availability_zone
                raise DeploymentInvalidMigratedFromJob,
                  "Failed to migrate instance group '#{migrated_from_job.name}' to '#{desired_job_name}', '#{migrated_from_job.name}' belongs to availability zone '#{instance.availability_zone}' and manifest specifies '#{migrated_from_job.availability_zone}'"
              end
            end

            if instance.availability_zone.nil?
              instance.update(availability_zone: migrated_from_job.availability_zone)
            end

            migrated_from_job_instances << instance

            @logger.debug("Migrating instance group '#{migrated_from_job.name}/#{instance.uuid} (#{instance.index})' to '#{desired_job.name}/#{instance.uuid} (#{instance.index})'")
          end
        end

        migrated_from_instances += migrated_from_job_instances
      end

      migrated_from_instances
    end
  end
end
