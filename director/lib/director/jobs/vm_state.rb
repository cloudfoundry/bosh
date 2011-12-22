module Bosh::Director
  module Jobs
    class VmState < BaseJob
      @queue = :normal

      def initialize(deployment_id)
        super
        @deployment_id = deployment_id
      end

      def perform
        vms = Models::Vm.filter(:deployment_id => @deployment_id)
        ThreadPool.new(:max_threads => 32).wrap do |pool|
          vms.each do |vm|
            pool.process do
              ips = []
              agent = AgentClient.new(vm.agent_id)
              begin
                agent_state = agent.get_state
                agent_state["networks"].each_value do |network|
                  ips << network["ip"]
                end
                index = agent_state["index"]
                job_name = agent_state["job"]["name"] if agent_state["job"]
                job_state = agent_state["job_state"]
                resource_pool = agent_state["resource_pool"]["name"] if agent_state["resource_pool"]
              rescue Bosh::Director::Client::TimeoutException
                job_state = "Unresponsive Agent"
                agent_state = []
              end
              vm_state = {:vm_cid => vm.cid,
                          :ips => ips,
                          :agent_id => vm.agent_id,
                          :job_name => job_name,
                          :index => index,
                          :job_state => job_state,
                          :resource_pool => resource_pool}
              @result_file.write(vm_state.to_json + "\n")
            end
          end
        end
      end
    end
  end
end
