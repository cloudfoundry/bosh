module Bosh::Director::DeploymentPlan
  class InstancePlanSorter
    def initialize(logger)
      @logger = logger
    end

    def sort(instance_plans)
      return [] if instance_plans.empty?

      @logger.debug('Sorting instance plan to update them always in the same order')

      @sorted_instance_plans = []
      bootstrap_instance_plan = instance_plans.find { |instance_plan| instance_plan.instance.bootstrap? }
      @sorted_instance_plans << bootstrap_instance_plan

      bootstrap_az = bootstrap_instance_plan.instance.availability_zone_name
      remaining_instance_plans = instance_plans - [bootstrap_instance_plan]

      sorted_instance_plans_for_bootstrap_az = sorted_instance_plans_in_special_az(bootstrap_az, remaining_instance_plans)
      remaining_instance_plans = remaining_instance_plans - sorted_instance_plans_for_bootstrap_az

      sorted_instance_plans_for_no_az = sorted_instance_plans_in_special_az(nil, remaining_instance_plans)
      remaining_instance_plans = remaining_instance_plans - sorted_instance_plans_for_no_az

      instance_plans_sorted_by_az = remaining_instance_plans.sort do |plan1, plan2|
        plan1.instance.availability_zone_name <=> plan2.instance.availability_zone_name
      end

      current_az = instance_plans_sorted_by_az.first.instance.availability_zone_name if instance_plans_sorted_by_az.any?
      instance_plans_in_current_az = []
      instance_plans_sorted_by_az.each do |instance_plan|
        if instance_plan.instance.availability_zone_name == current_az
          instance_plans_in_current_az << instance_plan
        else
          @sorted_instance_plans << sort_in_az(instance_plans_in_current_az)
          current_az = instance_plan.instance.availability_zone_name
          instance_plans_in_current_az = [instance_plan]
        end
      end
      @sorted_instance_plans << sort_in_az(instance_plans_in_current_az)
      @sorted_instance_plans.flatten
    end

    private
    def sort_in_az(instance_plans)
      instance_plans.sort { |plan1, plan2|
        "#{plan1.instance.job_name}/#{plan1.instance.uuid}" <=> "#{plan2.instance.job_name}/#{plan2.instance.uuid}"
      }
    end

    def sorted_instance_plans_in_special_az(az, instance_plans)
      all_instance_plans_for_az = instance_plans
                                    .select do |instance_plan|
        instance_plan.instance.availability_zone_name == az
      end
      sorted_instances_for_az = sort_in_az(all_instance_plans_for_az)
      @sorted_instance_plans << sorted_instances_for_az
      sorted_instances_for_az
    end
  end
end
