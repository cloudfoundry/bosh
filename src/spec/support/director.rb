module Bosh::Spec
  # Director information as a regular CLI user would see it.
  # State might not be necessarily in sync with what CPI thinks
  # (e.g. CPI might know about more VMs that director does).
  require_relative '../shared/support/table_helpers'

  class Director
    include Support::TableHelpers
    def initialize(runner, waiter, agents_base_dir, db, director_nats_config, logger)
      @runner = runner
      @waiter = waiter
      @agents_base_dir = agents_base_dir
      @db = db
      @logger = logger
      @nats_recording = []
      @director_nats_config = director_nats_config
    end

    def instances(options={deployment_name: Deployments::DEFAULT_DEPLOYMENT_NAME})
      instances_details(options).map do |instance_data|
        Bosh::Spec::Instance.new(
          @waiter,
          instance_data[:process_state],
          instance_data[:vm_cid],
          instance_data[:agent_id],
          instance_data[:resurrection],
          instance_data[:ips],
          instance_data[:az],
          instance_data[:id],
          instance_data[:job_name],
          instance_data[:index],
          instance_data[:ignore],
          instance_data[:bootstrap] == 'true',
          instance_data[:disk_cids],
          File.join(@agents_base_dir, "agent-base-dir-#{instance_data[:agent_id]}"),
          @director_nats_config,
          @logger,
        )
      end
    end

    def vms(options={})
      parse_table_with_ips(@runner.run('vms', options.merge(json: true))).map do |vm_data|
        Bosh::Spec::Vm.new(
          @waiter,
          vm_data[:process_state],
          vm_data[:vm_cid],
          vm_data[:ips],
          vm_data[:az],
          vm_data[:id],
          vm_data[:job_name],
          @director_nats_config,
          @logger,
          File.join(@agents_base_dir, "agent-base-dir-*"),
        )
      end
    end

    # vm always returns a vm
    def instance(job_name, index_or_id, options={deployment_name: Deployments::DEFAULT_DEPLOYMENT_NAME})
      find_instance(instances(options), job_name, index_or_id)
    end

    def find_instance(instances, job_name, index_or_id)
      instance = instances.detect { |instance| instance.job_name == job_name && (instance.index == index_or_id || instance.id == index_or_id)}
      instance || raise("Failed to find instance #{job_name}/#{index_or_id}. Found instances: #{instances.inspect}")
    end

    # wait_for_vm either returns a vm or nil after waiting for X seconds
    # (Do not add default timeout value to be more explicit in tests)
    def wait_for_vm(job_name, index, timeout_seconds, options = {deployment_name: Deployments::DEFAULT_DEPLOYMENT_NAME})
      start_time = Time.now
      loop do
        vm = instances(options).detect { |vm| !vm.vm_cid.empty? && vm.job_name == job_name && vm.index == index && vm.last_known_state != 'unresponsive agent' && vm.last_known_state != nil }
        return vm if vm
        break if Time.now - start_time >= timeout_seconds
        sleep(1)
      end

      @logger.info("Did not find VM after waiting for #{timeout_seconds}")
      nil
    end

    def wait_for_first_available_instance(timeout = 60, options = {deployment_name: Deployments::DEFAULT_DEPLOYMENT_NAME})
      @waiter.wait(timeout) { instances(options).first || raise('Must have at least 1 VM') }
    end

    def wait_for_first_available_vm(timeout = 60)
      @waiter.wait(timeout) { vms.first || raise('Must have at least 1 VM') }
    end

    def vms_vitals
      options = add_defaults({})
      parse_table_with_ips(@runner.run('vms --vitals', options))
    end

    def instances_vitals(options = {})
      options = add_defaults(options)
      parse_table(@runner.run('instances --vitals', options))
    end

    def instances_ps(options = {})
      options = add_defaults(options)
      parse_table(@runner.run('instances --ps', options))
    end

    def instances_ps_vitals(options = {})
      options = add_defaults(options)
      parse_table(@runner.run('instances --ps --vitals', options))
    end

    def instances_ps_vitals_failing(options = {})
      options = add_defaults(options)
      parse_table(@runner.run('instances --ps --vitals --failing', options))
    end

    def start_recording_nats
      Thread.new do
        EventMachine.run do
          @nats_client = NATS.connect(@director_nats_config) do
            @nats_client.subscribe('>') do |msg, reply, sub|
              @nats_recording << [sub, msg]
            end
          end
        end
      end
    end

    def finish_recording_nats
      @nats_client.close
      EventMachine.stop
      @nats_recording
    end

    def task(id)
      output = @runner.run("task #{id}", failure_expected: true) # permit failures, gocli task command fails if non-success. ruby cli return success despite task failure.
      failed = /Task (\d+) error/.match(output)
      return output, !failed
    end

    def raw_task_events(task_id)
      result = @runner.run("task #{task_id} --raw")
      event_list = []
      result.each_line do |line|
        begin
          event = JSON.parse(line)
          event_list << event if event
        rescue JSON::ParserError
        end
      end
      event_list
    end

    def kill_vm_and_wait_for_resurrection(vm, options={deployment_name: Deployments::DEFAULT_DEPLOYMENT_NAME})
      vm.kill_agent
      resurrected_vm = wait_for_vm(vm.job_name, vm.index, 300, options)

      wait_for_resurrection_to_finish

      if vm.vm_cid == resurrected_vm.vm_cid
        raise "expected vm to be recreated by cids match. original: #{vm.inspect}, new: #{resurrected_vm.inspect}"
      end

      resurrected_vm
    end

    def wait_for_resurrection_to_finish
      attempts = 0

      while attempts < 20
        attempts += 1
        resurrection_task = @db[:tasks].filter(
          username: 'hm',
          description: 'scan and fix',
          state: 'processing'
        )
        return unless resurrection_task.any?

        @logger.debug("Waiting for resurrection to finish, found resurrection tasks: #{resurrection_task.all}")
        sleep(0.5)
      end

      @logger.debug('Failed to wait for resurrection to complete')
    end

    private

    def add_defaults(options)
      options[:json] = true
      options[:deployment_name] ||= Deployments::DEFAULT_DEPLOYMENT_NAME
      options
    end

    def instances_details(options = {})
      parse_table_with_ips(@runner.run("instances --details", options.merge(json: true)))
    end

    def parse_table(output)
      parsed_table = table(output)

      parsed_table.map do |row|
        converted_row = row.dup

        row.each do |key, value|
          converted_row[key.to_sym] = value
        end

        converted_row
      end
    end

    def parse_table_with_ips(output)
      instances = parse_table(output)

      job_name_match_index = 1
      instance_id_match_index = 2

      instances.map do |instance|
        match_data = /(.*)\/([0-9a-f]{8}-[0-9a-f-]{27})/.match(instance[:instance])
        if match_data
          instance[:job_name] = match_data[job_name_match_index]
          instance[:id] = match_data[instance_id_match_index]

          instance[:ips] = instance[:ips].split("\n")
          instance['IPs'] = instance[:ips]

          instance[:disk_cids] = instance[:disk_cids].split("\n") if instance[:disk_cids]
          instance['Disk CIDs'] = instance[:disk_cids]
        end
        instance
      end
    end
  end
end
