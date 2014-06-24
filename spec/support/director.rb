module Bosh::Spec
  # Director information as a regular CLI user would see it.
  # State might not be necessarily in sync with what CPI thinks
  # (e.g. CPI might know about more VMs that director does).
  class Director
    def initialize(runner, agents_base_dir, director_nats_port, logger)
      @runner = runner
      @agents_base_dir = agents_base_dir
      @director_nats_port = director_nats_port
      @logger = logger
    end

    def vms
      vms_details.map do |vm_data|
        Vm.new(
          vm_data[:job_index],
          vm_data[:state],
          vm_data[:cid],
          vm_data[:agent_id],
          File.join(@agents_base_dir, "agent-base-dir-#{vm_data[:agent_id]}"),
          @director_nats_port,
          @logger,
        )
      end
    end

    # vm always returns a vm
    def vm(job_name_index)
      vm = vms.detect { |vm| vm.job_name_index == job_name_index }
      vm || raise("Failed to find vm #{job_name_index}")
    end

    # wait_for_vm either returns a vm or nil after waiting for X seconds
    # (Do not add default timeout value to be more explicit in tests)
    def wait_for_vm(job_name_index, timeout_seconds)
      start_time = Time.now
      loop do
        vm = vms.detect { |vm| vm.job_name_index == job_name_index }
        return vm if vm
        break if Time.now - start_time >= timeout_seconds
        sleep(1)
      end

      @logger.info("Did not find VM after waiting for #{timeout_seconds}")
      nil
    end

    def vms_vitals
      parse_table(@runner.run('vms --vitals'))
    end

    def vms_details
      parse_table(@runner.run('vms --details'))
    end

    private

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
      values_row = rows.shift

      headers = {}
      header_row.each_with_index do |row_line|
        row_titles = row_line.split('|').map(&:strip)
        row_titles.each_with_index do |row_title, key|
          headers[key] ||= ""
          headers[key] += " " + row_title
        end
      end

      headers = headers.values.map { |header| header.strip.gsub(/[\(\),]/, '').downcase.tr('/ ', '_').to_sym }

      values_row.map { |row| Hash[headers.zip(row.split('|').map(&:strip))] }
    end
  end
end
