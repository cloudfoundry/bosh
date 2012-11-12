module Bosh::WardenCloud

  module Helpers

    DEFAULT_SETTINGS_FILE = '/var/vcap/bosh/settings.json'

    def cloud_error(message)
      @logger.error(message) if @logger
      raise Bosh::Clouds::CloudError, message
    end

    def uuid(klass = nil)
      id = SecureRandom.uuid
      if klass
        id = sprintf('%s-%s', klass, id)
      end
      id
    end

    def sudo(cmd)
      sh(cmd, true)
    end

    def sh(cmd, su = false)
      runcmd = su == true ? "sudo -n #{cmd}" : cmd
      @logger.info "run '#{runcmd}'" if @logger
      Bosh::Exec.sh("#{runcmd}", yield: :on_false) do |result|
        yield result if block_given?
      end
    end

    def with_warden
      client = Warden::Client.new(@warden_unix_path)
      client.connect
      ret = yield client
      ret
    ensure
      client.disconnect if client
    end

    def agent_settings_file
      DEFAULT_SETTINGS_FILE
    end

    def generate_agent_env(vm_id, agent_id, networks, environment)
      vm_env = {
          'name' => vm_id,
          'id' => vm_id
      }

      env = {
          'vm' => vm_env,
          'agent_id' => agent_id,
          'networks' => networks,
          'disks' => { 'persistent' => {} },
      }
      env['env'] = environment if environment
      env.merge!(@agent_properties)
      env
    end

    def get_agent_env(handle)
      body = with_warden do |client|
        request = Warden::Protocol::RunRequest.new
        request.handle = handle
        request.privileged = true
        request.script = "cat #{agent_settings_file}"
        client.call(request).stdout
      end
      env = Yajl::Parser.parse(body)
      env
    end

    def set_agent_env(handle, env)
      tempfile = File.new("/tmp/agent-setting-#{Time.now.to_f}-#{Kernel.rand(100_000)}",'w')
      tempfile.write(Yajl::Encoder.encode(env))
      tempfile_in = "/tmp/#{Kernel.rand(100_000)}"
      tempfile.close
      # Here we copy the setting file to temp file in container, then mv it to
      # /var/vcap/bosh by privileged user.
      with_warden do |client|
        request = Warden::Protocol::CopyInRequest.new
        request.handle = handle
        request.src_path = tempfile.path
        request.dst_path = tempfile_in
        client.call(request)

        request = Warden::Protocol::RunRequest.new
        request.handle = handle
        request.privileged = true
        request.script = "mv #{tempfile_in} #{agent_settings_file}"
        client.call(request)
      end
    end

    def start_agent(handle)
      with_warden do |client|
        request = Warden::Protocol::SpawnRequest.new
        request.handle = handle
        request.privileged = true
        request.script = '/usr/sbin/runsvdir-start'
        client.call(request)
      end
    end

  end
end
