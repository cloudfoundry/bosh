# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class VmVitals < BaseJob

      @queue = :normal

      # @param [Integer] deployment_id Deployment id
      def initialize(deployment_id)
        super

        @deployment_id = deployment_id
      end

      def perform
        vms = Models::Vm.filter(:deployment_id => @deployment_id)
        ThreadPool.new(:max_threads => 32).wrap do |pool|
          vms.each do |vm|
            pool.process do
              vm_vitals = process_vm(vm)
              result_file.write(vm_vitals.to_json + "\n")
            end
          end
        end

        # task result
        nil
      end

      def process_vm(vm)
        # TODO: properly handle nil agent_id
        agent = AgentClient.new(vm.agent_id)
        index = nil
        job_name = nil
        job_state = nil
        job_vitals = nil

        begin
          agent_state = agent.vitals
          index = agent_state["index"]
          job_name = agent_state["job"]["name"] if agent_state["job"]
          job_state = agent_state["job_state"]
          job_vitals = agent_state["vitals"]
        rescue Bosh::Director::RpcTimeout
          job_state = "unresponsive agent"
        end

        {
          :vm_cid => vm.cid,
          :agent_id => vm.agent_id,
          :job_name => job_name,
          :index => index,
          :job_state => job_state,
          :vitals => job_vitals
        }
      end
    end
  end
end
