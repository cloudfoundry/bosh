module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateActiveVmCpisStep
        def initialize(logger, deployment_plan)
          @logger = logger
          @deployment_plan = deployment_plan
        end

        def perform
          cloud = CloudFactory.create_from_deployment_with_latest_configs(@deployment_plan.model)

          # puts "check 1 #{Models::Instance.all.count}"
          # puts Models::Instance.all[0]

          @deployment_plan.instance_groups_starting_on_deploy.each do |instance_group|
            # puts "IG: #{instance_group.instances}"
            # below is coming from deployment manifest
            instance_group.instances.each do |instance|
              # puts "I: #{instance}"

              instance_model = instance.model
              # puts "IM: #{instance_model.pretty_inspect}"
              # puts "check 2 #{Models::Instance.all.count}" # IMPOSTOR
              # puts "active_vm: #{instance_model.active_vm.pretty_inspect}"
              # puts "I...: #{instance.pretty_inspect}"
              next if instance_model.active_vm.nil?
              active_vm = instance_model.active_vm

              az = instance_model.availability_zone
              # puts "debug: #{az}"

              if az.empty?
                # reset cpi name to ""
                # puts "empty AZ"
                cpi_name = ""
              else
                # if that AZ is not in new cloud config, an error will be thrown
                cpi_name = cloud.get_name_for_az(az)
              end

              # puts "old / new: #{active_vm.cpi} / #{cpi_name}"

              if cpi_name != active_vm.cpi
                @logger.debug("Changing CPI name for instance #{instance_model} from #{active_vm.cpi} to #{cpi_name}")
                active_vm.cpi = cpi_name
                active_vm.save
              end
            end
          end

        end

        private

        def update_jobs
          @logger.info('Updating instances')
          @multi_job_updater.run(
            @base_job,
            @deployment_plan.ip_provider,
            @deployment_plan.instance_groups_starting_on_deploy,
          )
        end
      end
    end
  end
end
