module Bosh::Director
  module Jobs
    class VmState < BaseJob
      TIMEOUT = 5

      @queue = :normal

      def self.job_type
        :vms
      end

      # @param [Integer] deployment_id Deployment id
      def initialize(deployment_id, format)
        @deployment_id = deployment_id
        @format = format
      end

      def perform
        @domain = Models::Dns::Domain.find(name: Config.dns_domain_name, type: "NATIVE") if Config.dns_enabled?

        vms = Models::Vm.filter(:deployment_id => @deployment_id)
        ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
          vms.each do |vm|
            pool.process do
              vm_state = process_vm(vm)
              result_file.write(vm_state.to_json + "\n")
            end
          end
        end

        # task result
        nil
      end

      def process_vm(vm)
        ips = []
        dns_records = []
        job_name = nil
        job_state = nil
        resource_pool = nil
        job_vitals = nil
        job_index = nil
        processes = []

        begin
          agent = AgentClient.with_vm(vm, :timeout => TIMEOUT)
          agent_state = agent.get_state(@format)
          agent_state["networks"].each_value do |network|
            ips << network["ip"]
          end

          job_index = get_index(agent_state)

          job_name = agent_state["job"]["name"] if agent_state["job"]
          job_state = agent_state["job_state"]
          if agent_state["resource_pool"]
            resource_pool = agent_state["resource_pool"]["name"]
          end
          if agent_state["vitals"]
            job_vitals = agent_state["vitals"]
          end
          processes = agent_state["processes"] if agent_state["processes"]
        rescue Bosh::Director::RpcTimeout
          job_state = "unresponsive agent"
        end

        if @domain
          ips.each do |ip|
            records = Models::Dns::Record.filter(domain_id: @domain.id, type: "A", content: ip)
            records.each { |record| dns_records << record.name } unless records.empty?
          end
          dns_records.sort_by! { |name| -name.split('.').first.length }
        end

        vm_apply_spec = vm.apply_spec

        {
          :vm_cid => vm.cid,
          :disk_cid => vm.instance ? vm.instance.persistent_disk_cid : nil,
          :ips => ips,
          :dns => dns_records,
          :agent_id => vm.agent_id,
          :job_name => job_name,
          :index => job_index,
          :job_state => job_state,
          :resource_pool => resource_pool,
          :vm_type => vm_apply_spec && vm_apply_spec['vm_type'] ? vm_apply_spec['vm_type']['name'] : nil,
          :vitals => job_vitals,
          :processes => processes,
          :resurrection_paused => vm.instance ? vm.instance.resurrection_paused : nil,
          :availability_zone => vm.instance ? vm.instance.availability_zone : nil,
          :instance_id => vm.instance ? vm.instance.uuid : nil,
          :is_bootstrap => vm.instance ? vm.instance.bootstrap : false
        }
      end

      private

      def get_index(agent_state)
        index = agent_state["index"]

        # Postgres cannot coerce an empty string to integer, and fails on Models::Instance.find
        index = nil if index.is_a?(String) && index.empty?

        index
      end
    end
  end
end
