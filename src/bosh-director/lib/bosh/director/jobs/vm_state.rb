module Bosh::Director
  module Jobs
    class VmState < BaseJob
      TIMEOUT = 5

      @queue = :urgent

      def self.job_type
        :vms
      end

      def initialize(deployment_id, format, state_for_missing_vms = false)
        @deployment_id = deployment_id
        @format = format
        @state_for_missing_vms = state_for_missing_vms
      end

      def perform
        instances = Models::Instance.filter(:deployment_id => @deployment_id)
        instances = instances.reject { |i| i.active_vm.nil? } unless @state_for_missing_vms
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          instances.each do |instance|
            pool.process do
              vm_state = process_instance(instance)
              task_result.write(vm_state.to_json + "\n")
            end
          end
        end

        # task result
        nil
      end

      def process_instance(instance)
        dns_records = []

        job_state, job_vitals, processes, _ = vm_details(instance)

        if dns_manager.dns_enabled?
          dns_records = dns_manager.find_dns_record_names_by_instance(instance)
          dns_records.sort_by! { |name| -(name.split('.').first.length) }
        end

        vm_type_name = instance.spec_p('vm_type.name')

        {
          :vm_cid => instance.vm_cid,
          :disk_cid => instance.managed_persistent_disk_cid,
          :disk_cids => instance.active_persistent_disks.collection.map{|d| d.model.disk_cid},
          :ips => ips(instance),
          :dns => dns_records,
          :agent_id => instance.agent_id,
          :job_name => instance.job,
          :index => instance.index,
          :job_state => job_state,
          :state => instance.state,
          :resource_pool => vm_type_name,
          :vm_type => vm_type_name,
          :vitals => job_vitals,
          :processes => processes,
          :resurrection_paused => instance.resurrection_paused,
          :az => instance.availability_zone,
          :id => instance.uuid,
          :bootstrap => instance.bootstrap,
          :ignore => instance.ignore
        }
      end

      private

      def ips(instance)
        result = instance.ip_addresses.map {|ip| NetAddr::CIDR.create(ip.address).ip }
        if result.empty? && instance.spec
          result = instance.spec['networks'].map {|_, network| network['ip']}
        end
        result
      end

      def vm_details(instance)
        ips = []
        processes = []
        job_vitals = nil
        job_state = nil

        if instance.vm_cid
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
        end

        return job_state, job_vitals, processes, ips
      end

      def get_index(agent_state)
        index = agent_state['index']

        # Postgres cannot coerce an empty string to integer, and fails on Models::Instance.find
        index = nil if index.is_a?(String) && index.empty?

        index
      end
    end
  end
end
