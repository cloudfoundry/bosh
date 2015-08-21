module Bosh::Spec
  class Vm
    attr_reader :job_name_index, :last_known_state, :cid, :agent_id

    def initialize(
      waiter,
      job_name_index,
      job_state,
      cid,
      agent_id,
      agent_base_dir,
      nats_port,
      logger
    )
      @waiter = waiter
      @job_name_index = job_name_index
      @last_known_state = job_state
      @cid = cid
      @agent_id = agent_id
      @agent_base_dir = agent_base_dir
      @nats_port = nats_port
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
      @logger.info("Failing job #{@cid}")
      NATS.start(uri: "nats://localhost:#{@nats_port}") do
        msg = Yajl::Encoder.encode(
          method: 'set_dummy_status',
          status: 'failing',
          reply_to: 'integration.tests',
        )
        NATS.publish("agent.#{@agent_id}", msg) { NATS.stop }
      end
    end

    def fail_start_task
      @logger.info("Failing task #{@cid}")
      NATS.start(uri: "nats://localhost:#{@nats_port}") do
        msg = Yajl::Encoder.encode(
          method: 'set_task_fail',
          status: 'fail_task',
          reply_to: 'integration.tests',
        )
        NATS.publish("agent.#{@agent_id}", msg) { NATS.stop }
      end
    end

    def unblock_package
      @waiter.wait(300) do
        package_dir = package_path('blocking_package')
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

      raise('Failed to get errand dir') unless File.exists?(job_dir_path)
      FileUtils.touch(File.join(job_dir_path, 'unblock_errand'))
    end

    def job_path(job_name)
      File.join(@agent_base_dir, 'jobs', job_name)
    end

    def kill_agent
      @logger.info("Killing agent #{@cid}")
      Process.kill('INT', @cid.to_i)
    end

    def get_state
      spec_path = File.join(@agent_base_dir, 'bosh', 'spec.json')
      Yajl::Parser.parse(File.read(spec_path))
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
