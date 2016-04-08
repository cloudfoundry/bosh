module Bosh::Director
  class PostDeploymentScriptRunner

    def self.run_post_deploys_after_resurrection(deployment)
      return unless Config.enable_post_deploy
      instances = Models::Instance.filter(deployment: deployment).exclude(vm_cid: nil).all
      agent_options = {
          timeout: 10,
          retry_methods: {get_state: 0}
      }

      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        instances.each do |instance|
          pool.process do
            agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id, agent_options)
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
      return unless Config.enable_post_deploy
      ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
        deployment_plan.jobs.each do |job|
          job.instances.select{|instance| instance.model[:vm_cid] != nil && instance.model.state != "stopped"}.each do |instance|
            pool.process do
              instance.agent_client.run_script('post-deploy', {})
            end
          end
        end
      end
    end

  end
end