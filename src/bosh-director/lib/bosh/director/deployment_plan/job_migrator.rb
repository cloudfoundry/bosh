module Bosh::Director
  class DeploymentPlan::MigratedFromJob < Struct.new(:name, :availability_zone); end

  class DeploymentPlan::JobMigrator
    def initialize(deployment_plan, logger)
      @deployment_plan = deployment_plan
      @logger = logger
    end

    def find_existing_instances(desired_instance_group)
      instances = []
      existing_instances = @deployment_plan.instance_models.select { |model| model.job == desired_instance_group.name }
      existing_instances.each do |existing_instance|
        instances << existing_instance
      end

      unless desired_instance_group.migrated_from.to_a.empty?
        migrated_from_instances = all_migrated_from_instances(
          desired_instance_group.migrated_from,
          desired_instance_group
        )

        instances += migrated_from_instances
      end

      instances.uniq
    end

    private

    def all_migrated_from_instances(migrated_from_instance_groups, desired_instance_group)
      desired_instance_group_name = desired_instance_group.name
      migrated_from_instances = []

      migrated_from_instance_groups.each do |migrated_from_instance_group|
        existing_instance_group = @deployment_plan.instance_group(migrated_from_instance_group.name)
        if existing_instance_group && existing_instance_group.name != desired_instance_group.name
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate instance group '#{migrated_from_instance_group.name}' to '#{desired_instance_group_name}'. " +
              'A deployment can not migrate an instance group and also specify it. ' +
              "Please remove instance group '#{migrated_from_instance_group.name}'."
        end

        other_instance_groups = @deployment_plan.instance_groups.reject { |job| job.name == desired_instance_group_name }

        migrate_to_multiple_instance_groups = other_instance_groups.any? do |job|
          job.migrated_from.any? do |other_migrated_from_instance_group|
            other_migrated_from_instance_group.name == migrated_from_instance_group.name
          end
        end

        if migrate_to_multiple_instance_groups
          raise DeploymentInvalidMigratedFromJob,
            "Failed to migrate instance group '#{migrated_from_instance_group.name}' to '#{desired_instance_group_name}'. An instance group may be migrated to only one instance group."
        end

        migrated_from_instance_group_instances = []

        @deployment_plan.existing_instances.each do |instance|
          if instance.job == migrated_from_instance_group.name
            if instance.availability_zone.nil? &&
              migrated_from_instance_group.availability_zone.nil?  &&
              desired_instance_group.availability_zones.to_a.compact.any?
              raise DeploymentInvalidMigratedFromJob,
                "Failed to migrate instance group '#{migrated_from_instance_group.name}' to '#{desired_instance_group_name}', availability zone of '#{migrated_from_instance_group.name}' is not specified"
            end

            if !migrated_from_instance_group.availability_zone.nil? && !instance.availability_zone.nil?
              if migrated_from_instance_group.availability_zone != instance.availability_zone
                raise DeploymentInvalidMigratedFromJob,
                  "Failed to migrate instance group '#{migrated_from_instance_group.name}' to '#{desired_instance_group_name}', '#{migrated_from_instance_group.name}' belongs to availability zone '#{instance.availability_zone}' and manifest specifies '#{migrated_from_instance_group.availability_zone}'"
              end
            end

            if instance.availability_zone.nil?
              instance.update(availability_zone: migrated_from_instance_group.availability_zone)
            end

            migrated_from_instance_group_instances << instance

            @logger.debug("Migrating instance group '#{migrated_from_instance_group.name}/#{instance.uuid} (#{instance.index})' to '#{desired_instance_group.name}/#{instance.uuid} (#{instance.index})'")
          end
        end

        migrated_from_instances += migrated_from_instance_group_instances
      end

      migrated_from_instances
    end
  end
end
