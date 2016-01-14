module Bosh::Director
  module Jobs
    class VmState < BaseJob
      TIMEOUT = 5

      @queue = :normal

      def self.job_type
        :vms
      end

      def initialize(deployment_id, format)
        @deployment_id = deployment_id
        @format = format
      end

      def perform
        instances = Models::Instance.filter(:deployment_id => @deployment_id).exclude(vm_cid: nil)
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          instances.each do |instance|
            pool.process do
              vm_state = process_instance(instance)
              result_file.write(vm_state.to_json + "\n")
            end
          end
        end

        # task result
        nil
      end

      def process_instance(instance)
        ips = []
        dns_records = []
        job_state = nil
        job_vitals = nil
        processes = []

        begin
          agent = AgentClient.with_vm_credentials_and_agent_id(instance.credentials, instance.agent_id, :timeout => TIMEOUT)
          agent_state = agent.get_state(@format)
          agent_state['networks'].each_value do |network|
            ips << network['ip']
          end

          job_state = agent_state['job_state']
          if agent_state['vitals']
            job_vitals = agent_state['vitals']
          end
          processes = agent_state['processes'] if agent_state['processes']
        rescue Bosh::Director::RpcTimeout
          job_state = 'unresponsive agent'
        end

        if dns_manager.dns_enabled?
          dns_records = dns_manager.find_dns_record_names_by_instance(instance)
          dns_records.sort_by! { |name| -(name.split('.').first.length) }
        end

        vm_type_name = instance.spec && instance.spec['vm_type'] ? instance.spec['vm_type']['name'] : nil

        {
          :vm_cid => instance.vm_cid,
          :disk_cid => instance.persistent_disk_cid,
          :ips => ips,
          :dns => dns_records,
          :agent_id => instance.agent_id,
          :job_name => instance.job,
          :index => instance.index,
          :job_state => job_state,
          :resource_pool => vm_type_name,
          :vm_type => vm_type_name,
          :vitals => job_vitals,
          :processes => processes,
          :resurrection_paused => instance.resurrection_paused,
          :az => instance.availability_zone,
          :id => instance.uuid,
          :bootstrap => instance.bootstrap
        }
      end

      private

      def get_index(agent_state)
        index = agent_state['index']

        # Postgres cannot coerce an empty string to integer, and fails on Models::Instance.find
        index = nil if index.is_a?(String) && index.empty?

        index
      end
    end
  end
end
