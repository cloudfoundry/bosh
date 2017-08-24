module Bosh::Spec
  class Instance
    attr_reader :last_known_state, :vm_cid, :agent_id, :resurrection, :ips, :availability_zone, :id, :job_name, :index, :ignore, :bootstrap, :disk_cids

    def initialize(
      waiter,
      job_state,
      vm_cid,
      agent_id,
      resurrection,
      ips,
      availability_zone,
      instance_uuid,
      job_name,
      index,
      ignore,
      bootstrap,
      disk_cids,
      agent_base_dir,
      nats_config,
      logger
    )
      @waiter = waiter
      @last_known_state = job_state
      @vm_cid = vm_cid
      @agent_id = agent_id
      @resurrection = resurrection
      @ips = ips
      @availability_zone = availability_zone
      @id = instance_uuid
      @job_name = job_name
      @index = index
      @ignore = ignore
      @bootstrap = bootstrap
      @disk_cids = disk_cids
      @agent_base_dir = agent_base_dir
      @nats_config = nats_config
      @logger = logger
    end

    def read_job_template(template_name, template_path)
      read_file(File.join('jobs', template_name, template_path))
    end

    def read_file(file_name)
      File.read(file_path(file_name))
    end

    def file_path(file_name)
      File.join(@agent_base_dir, file_name)
    end

    def write_job_log(file_path, file_contents)
      log_path = File.join(jobs_logs_path, file_path)
      FileUtils.mkdir_p(File.split(log_path).first)
      File.write(log_path, file_contents)
    end

    def write_agent_log(file_path, file_contents)
      log_path = File.join(agent_logs_path, file_path)
      FileUtils.mkdir_p(File.split(log_path).first)
      File.write(log_path, file_contents)
    end

    def fail_job
      @logger.info("Failing job #{@vm_cid}")
      NATS.start(@nats_config) do
        msg = JSON.dump(
          method: 'set_dummy_status',
          status: 'failing',
          reply_to: 'integration.tests',
        )
        NATS.publish("agent.#{@agent_id}", msg) { NATS.stop }
      end
    end

    def fail_start_task
      @logger.info("Failing task #{@vm_cid}")
      NATS.start(@nats_config) do
        msg = JSON.dump(
          method: 'set_task_fail',
          status: 'fail_task',
          reply_to: 'integration.tests',
        )
        NATS.publish("agent.#{@agent_id}", msg) { NATS.stop }
      end
    end

    def unblock_package
      package_dir = package_path('blocking_package')
      @waiter.wait(300) do
        raise('Must find package dir') unless File.exists?(package_dir)
        FileUtils.touch(File.join(package_dir, 'unblock_packaging'))
      end
    end

    def package_path(package_name)
      File.join(@agent_base_dir, 'packages', package_name)
    end

    def unblock_errand(job_name)
      job_dir_path = job_path(job_name)
      @logger.debug("Unblocking package at #{job_dir_path}")

      @waiter.wait(15) do
        raise('Must find errand dir') unless File.exists?(job_dir_path)
        FileUtils.touch(File.join(job_dir_path, 'unblock_errand'))
      end
    end

    def job_path(job_name)
      File.join(@agent_base_dir, 'jobs', job_name)
    end

    def kill_agent
      @logger.info("Killing agent #{@vm_cid}")
      Process.kill('INT', @vm_cid.to_i)
    end

    def get_state
      JSON.parse(read_file(File.join('bosh', 'spec.json')))
    end

    def read_etc_hosts
      read_file(File.join('bosh', 'etc_hosts'))
    end

    def dns_records
      JSON.parse(read_file(File.join('instance', 'dns', 'records.json')))
    end

    private

    def jobs_logs_path
      File.join(@agent_base_dir, 'sys', 'log')
    end

    def agent_logs_path
      File.join(@agent_base_dir, 'bosh', 'log')
    end
  end
end
