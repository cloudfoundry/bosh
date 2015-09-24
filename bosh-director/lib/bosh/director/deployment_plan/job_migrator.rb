module Bosh::Director
  class DeploymentPlan::MigratedFromJob < Struct.new(:name, :az); end
  class DeploymentPlan::InstanceWithAZ < Struct.new(:model, :az); end

  class DeploymentPlan::JobMigrator
    def initialize(deployment_plan, logger)
      @deployment_plan = deployment_plan
      @logger = logger
    end

    def find_existing_instances_with_azs(desired_job)
      instances = []
      desired_job.existing_instances.each do |existing_instance|
        instances << DeploymentPlan::InstanceWithAZ.new(existing_instance, existing_instance.availability_zone)
      end

      unless desired_job.migrated_from.to_a.empty?
        migrated_from_instances = all_migrated_from_instances(
          desired_job.migrated_from,
          desired_job.name
        )

        instances += migrated_from_instances
      end

      instances
    end

    def all_migrated_from_instances(migrated_from_jobs, desired_job_name)
      migrated_from_instances = []

      migrated_from_jobs.each do |migrated_from_job|
        if @deployment_plan.job(migrated_from_job.name)
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate job '#{migrated_from_job.name}' to '#{desired_job_name}', deployment still contains it"
        end

        other_jobs = @deployment_plan.jobs.reject { |job| job.name == desired_job_name }
        if other_jobs.any? do |job|
          job.migrated_from.any? do |other_migrated_from_job|
            other_migrated_from_job.name == migrated_from_job.name
          end
        end
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate job '#{migrated_from_job.name}' to '#{desired_job_name}', can only be used in one job to migrate"
        end

        migrated_from_job_instances = []

        @deployment_plan.existing_instances.each do |instance|
          if instance.job == migrated_from_job.name
            az = migrated_from_job.az || instance.availability_zone
            migrated_from_job_instances << DeploymentPlan::InstanceWithAZ.new(instance, az)
          end
        end

        if migrated_from_job_instances.empty?
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate job '#{migrated_from_job.name}' to '#{desired_job_name}', unknown job '#{migrated_from_job.name}'"
        end

        @logger.debug("Migrating job '#{migrated_from_job.name}' to '#{desired_job_name}'")

        migrated_from_instances += migrated_from_job_instances
      end

      migrated_from_instances
    end
  end
end
