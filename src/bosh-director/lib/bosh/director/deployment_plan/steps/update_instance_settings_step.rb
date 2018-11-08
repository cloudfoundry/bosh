module Bosh::Director
  module DeploymentPlan
    module Steps
      class UpdateInstanceSettingsStep
        def initialize(instance)
          @instance = instance
        end

        def perform(report)
          instance_model = @instance.model.reload

          disk_associations = instance_model.active_persistent_disks.collection.reject do |disk|
            disk.model.managed?
          end

          disk_associations.map! do |disk|
            { 'name' => disk.model.name, 'cid' => disk.model.disk_cid }
          end

          vm = report.vm
          AgentClient.with_agent_id(vm.agent_id, instance_model.name).update_settings(Config.trusted_certs, disk_associations)
          vm.update(trusted_certs_sha1: ::Digest::SHA1.hexdigest(Config.trusted_certs))

          instance_model.update(cloud_properties: JSON.dump(@instance.cloud_properties))
        end
      end
    end
  end
end
