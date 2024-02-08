module Bosh::Director
  module DeploymentPlan
    module Steps
      class PrepareInstanceStep
        def initialize(instance_plan, use_active_vm: true)
          @instance_plan = instance_plan
          @use_active_vm = use_active_vm
          @blobstore = App.instance.blobstores.blobstore
        end

        def perform(_report)
          spec = InstanceSpec.create_from_instance_plan(@instance_plan)
          instance_model = @instance_plan.instance.model

          if @use_active_vm
            spec = spec.as_apply_spec
            agent_id = instance_model.agent_id
            name = instance_model.name
            raise 'no active VM available to prepare for instance' if agent_id.nil?

            stemcell_api_version = instance_model.active_vm.stemcell_api_version
          else
            spec = spec.as_jobless_apply_spec
            vm = instance_model.most_recent_inactive_vm
            raise 'no inactive VM available to prepare for instance' if vm.nil?

            agent_id = vm.agent_id
            name = vm.instance.name
            stemcell_api_version = vm.stemcell_api_version
          end

          spec = add_signed_urls(spec) if @blobstore.can_sign_urls?(stemcell_api_version)

          AgentClient.with_agent_id(agent_id, name).prepare(spec)
        end

        def add_signed_urls(spec)
          spec['packages'].each do |_, package|
            package['signed_url'] = @blobstore.sign(package['blobstore_id'], 'get')
            package['blobstore_headers'] = @blobstore.headers unless @blobstore.headers.empty?
          end
          spec
        end
      end
    end
  end
end
