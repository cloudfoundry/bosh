module Bosh::Director::ConfigServer
  class VariablesHandler

    def self.update_instance_plans_variable_set_id(instance_groups, deploying, current_variable_set)
      instance_groups.each do |instance_group|
        instance_group.unignored_instance_plans.each do |instance_plan|
          if deploying
            instance_plan.instance.variable_set = current_variable_set
          end
        end
      end
    end

    def self.mark_new_current_variable_set(deployment)
      Bosh::Director::Config.db.transaction do
        current_variable_set = deployment.current_variable_set

        deployment.variable_sets.each do |variable_set|
          if variable_set != current_variable_set
            variable_set.update(deployed_successfully: false)
          end
        end

        current_variable_set.update(deployed_successfully: true)
      end
    end

    def self.remove_unused_variable_sets(deployment, instance_groups)
      current_variable_set = deployment.current_variable_set
      deployment.variable_sets.each do |variable_set|
        variable_set_usage = 0
        instance_groups.each do |instance_group|
          variable_set_usage += instance_group.needed_instance_plans.select{ |instance_plan| instance_plan.instance.variable_set.id == variable_set.id }.size
        end

        if variable_set_usage == 0 && variable_set.id != current_variable_set.id
          variable_set.delete
        end
      end
    end
  end
end
