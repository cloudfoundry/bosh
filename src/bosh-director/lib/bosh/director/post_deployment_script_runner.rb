module Bosh::Director
  class PostDeploymentScriptRunner

    def self.run_post_deploys_after_resurrection(deployment)
      instances = Models::Instance.filter(deployment: deployment).reject { |i| i.active_vm.nil? }
      agent_options = {
          timeout: 10,
          retry_methods: {get_state: 0}
      }

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process do
            agent = AgentClient.with_agent_id(instance.agent_id, instance.name, agent_options)
            begin
              agent.run_script('post-deploy', {})
            rescue Bosh::Director::RpcTimeout
              # Ignoring timeout errors
            end
          end
        end
      end
    end

    def self.run_post_deploys_after_deployment(deployment_plan)
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        deployment_plan.instance_groups.each do |instance_group|
          # No ignored instances will ever come to this point as they were filtered out earlier
          # BUT JUST IN CASE, check for the ignore flag
          instance_group.instances.select do |instance|
            instance.model.has_important_vm?
          end.each do |instance|
            pool.process do
              instance.agent_client.run_script('post-deploy', {})
            end
          end
        end
      end
    end
  end
end
