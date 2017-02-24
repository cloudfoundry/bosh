module Bosh::Spec
  # Director information as a regular CLI user would see it.
  # State might not be necessarily in sync with what CPI thinks
  # (e.g. CPI might know about more VMs that director does).
  class Director
    def initialize(runner, waiter, agents_base_dir, director_nats_port, db, logger)
      @runner = runner
      @waiter = waiter
      @agents_base_dir = agents_base_dir
      @director_nats_port = director_nats_port
      @db = db
      @logger = logger
      @nats_recording = []
    end

    def vms(deployment_name = '', options={})
      vms_details(deployment_name, options).map do |vm_data|
        Bosh::Spec::Vm.new(
          @waiter,
          vm_data[:state],
          vm_data[:cid],
          vm_data[:agent_id],
          vm_data[:resurrection],
          vm_data[:ips],
          vm_data[:az],
          vm_data[:id],
          vm_data[:job_name],
          vm_data[:index],
          vm_data[:ignore],
          File.join(@agents_base_dir, "agent-base-dir-#{vm_data[:agent_id]}"),
          @director_nats_port,
          @logger,
        )
      end
    end

    def instances(deployment_name = '', options={})
      instances_output = @runner.run("instances #{deployment_name} --details", options)
      instances = parse_table_with_ips(instances_output, :instance)

      instances.map do |instance_data|
        Bosh::Spec::Instance.new(
          instance_data[:id],
          instance_data[:job_name],
          instance_data[:index],
          !instance_data[:bootstrap].empty?,
          instance_data[:az],
          instance_data[:disk_cid],
          instance_data[:vm_cid]
        )
      end
    end

    # vm always returns a vm
    def vm(job_name, index_or_id, options={})
      deployment_name = options.fetch(:deployment, '')
      find_vm(vms(deployment_name, options), job_name, index_or_id)
    end

    def find_vm(vms, job_name, index_or_id)
      vm = vms.detect { |vm| vm.job_name == job_name && (vm.index == index_or_id.to_s || vm.instance_uuid == index_or_id.to_s)}
      vm || raise("Failed to find vm #{job_name}/#{index_or_id}")
    end

    # wait_for_vm either returns a vm or nil after waiting for X seconds
    # (Do not add default timeout value to be more explicit in tests)
    def wait_for_vm(job_name, index, timeout_seconds, options = {})
      start_time = Time.now
      loop do
        vm = vms('', options).detect { |vm| vm.job_name == job_name && vm.index == index && vm.last_known_state != 'unresponsive agent' && vm.last_known_state != nil }
        return vm if vm
        break if Time.now - start_time >= timeout_seconds
        sleep(1)
      end

      @logger.info("Did not find VM after waiting for #{timeout_seconds}")
      nil
    end

    def wait_for_first_available_vm(timeout = 60)
      @waiter.wait(timeout) { vms.first || raise('Must have at least 1 VM') }
    end

    def vms_vitals
      parse_table_with_ips(@runner.run('vms --vitals'))
    end

    def instances_vitals(options = {})
      parse_table(@runner.run('instances --vitals', options))
    end

    def instances_ps(options = {})
      parse_table(@runner.run('instances --ps', options))
    end

    def instances_ps_vitals(options = {})
      parse_table(@runner.run('instances --ps --vitals', options))
    end

    def instances_ps_vitals_failing(options = {})
      parse_table(@runner.run('instances --ps --vitals --failing', options))
    end

    def start_recording_nats
      # have to read NATS port on main thread, or the new thread hangs on startup (?!)
      nats_uri = "nats://localhost:#{@director_nats_port}"

      Thread.new do
        EventMachine.run do
          @nats_client = NATS.connect(uri: nats_uri, ssl: true) do
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
      output = @runner.run("task #{id}")
      failed = /Task (\d+) error/.match(output)
      return output, !failed
    end

    def raw_task_events(task_id)
      result = @runner.run("task #{task_id} --raw")
      event_list = []
      result.each_line do |line|
        begin
          event = Yajl::Parser.new.parse(line)
          event_list << event if event
        rescue Yajl::ParseError
        end
      end
      event_list
    end

    def kill_vm_and_wait_for_resurrection(vm, options={})
      vm.kill_agent
      resurrected_vm = wait_for_vm(vm.job_name, vm.index, 300, options)

      wait_for_resurrection_to_finish

      if vm.cid == resurrected_vm.cid
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

    def vms_details(deployment_name, options = {})
      parse_table_with_ips(@runner.run("vms #{deployment_name} --details", options))
    end

    def parse_table(output)
      rows = []
      current_row = -1

      output.lines.each do |line|
        if line =~ /^\+/
          current_row += 1
        elsif line =~ /^\|/
          rows[current_row] ||= []
          rows[current_row] << line
        end
      end

      header_row = rows.shift
      return [] unless header_row

      headers = {}

      header_row.each_with_index do |row_line|
        row_titles = row_line.split('|').map(&:strip)
        row_titles.each_with_index do |row_title, key|
          headers[key] ||= ""
          headers[key] += " " + row_title
        end
      end

      headers = headers.values.map { |header| header.strip.sub(' %','').gsub(/[\%\(\),]/, '').downcase.tr('/ ', '_').to_sym }

      rows.map do |row|
        # rows is an array of arrays, convert to array of hashes, where keys are downcased titles
        row.map { |row| Hash[headers.zip(row.split('|').map(&:strip))] }
      end.flatten
    end

    def parse_table_with_ips(output, table_type=:vm)
      vms = parse_table(output)

      job_name_match_index = 1
      instance_id_match_index = 2
      index_match_index = 3
      bootstrap_match_index = 4

      vms.each do |vm|
        match_data = /(.*)\/([0-9a-f]{8}-[0-9a-f-]{27})\s\((\d+)\)(\*?)/.match(vm[table_type])
        if row_is_ip_address_for_previous_row(match_data)
          vm[:is_ip_address_for_previous_row] = true
        else
          vm[:job_name] = match_data[job_name_match_index]
          vm[:id] = match_data[instance_id_match_index]
          vm[:bootstrap] = match_data[bootstrap_match_index]
          vm[:index] = match_data[index_match_index]
        end
      end

      # collapse rows for single VM with multiple IPs
      result = []
      vms.each_with_index do |vm, i|
        if vm[:is_ip_address_for_previous_row]
          vms[i-1][:ips] = Array(vms[i-1][:ips])
          vms[i-1][:ips] << vm[:ips]
        else
          result << vm
        end
      end

      result
    end

    def row_is_ip_address_for_previous_row(match_data)
      match_data.nil? || match_data.size != 5
    end
  end
end
