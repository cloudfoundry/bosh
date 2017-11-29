module Bosh::Director
  module DeploymentPlan
    module Stages
      class UpdateActiveVmCpisStage
        def initialize(logger, deployment_plan)
          @logger = logger
          @deployment_plan = deployment_plan
        end

        def perform
          cloud = CloudFactory.create_with_latest_configs(@deployment_plan.model)

          @deployment_plan.instance_groups_starting_on_deploy.each do |instance_group|
            next if instance_group.instances.nil?

            instance_group.instances.each do |instance|
              instance_model = instance.model
              next if instance_model.active_vm.nil?
              active_vm = instance_model.active_vm

              az = instance_model.availability_zone

              if az.nil? || az.empty?
                cpi_name = ""
              else
                cpi_name = cloud.get_name_for_az(az)
              end

              # Weird situation:
              if cpi_name.empty? && !active_vm.cpi.empty?
                @logger.debug('Active VM has a cpi_name specified, but we are changing cpi_name to nil.')
              end

              if cpi_name != active_vm.cpi
                @logger.debug("Changing CPI name for instance #{instance_model} from #{active_vm.cpi} to #{cpi_name}")
                active_vm.cpi = cpi_name
                active_vm.save
              end
            end
          end
        end
      end
    end
  end
end
