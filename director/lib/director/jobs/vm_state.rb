module Bosh::Director
  module Jobs
    class VmState < BaseJob
      @queue = :normal

      def initialize(deployment_id)
        @deployment_id = deployment_id
        @result_file = Config.result
      end

      def perform
        vms = Models::Vm.filter(:deployment_id => @deployment_id)
        ThreadPool.new(:max_threads => 32).wrap do |pool|
          vms.each do |vm|
            pool.process do
              ips = ""
              agent = AgentClient.new(vm.agent_id)
              agent_state = agent.get_state
              agent_state["networks"].each_value do |network|
                ips += network["ip"] + " "
              end
              job_name = nil
              job_name = agent_state["job"]["name"] if agent_state["job"]
              index = agent_state["index"]

              vm_state = {:vm_cid => vm.cid,
                          :ips => ips,
                          :agent_id => agent_state["agent_id"],
                          :job_state => agent_state["job_state"],
                          :job_name => job_name,
                          :index => index,
                          :resource_pool => agent_state["resource_pool"]["name"]}
              @result_file.write(vm_state.to_json + "\n")
            end
          end
        end
      end
    end
  end
end
