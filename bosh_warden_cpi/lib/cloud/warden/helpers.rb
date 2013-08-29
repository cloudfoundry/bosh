module Bosh::WardenCloud

  module Helpers

    DEFAULT_SETTINGS_FILE = '/var/vcap/bosh/settings.json'
    UMOUNT_GUARD_RETRIES = 60
    UMOUNT_GUARD_SLEEP = 3

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
      @logger.info "run 'sudo -n #{cmd}'" if @logger
      Bosh::Exec.sh("sudo -n #{cmd}", yield: :on_false) do |result|
        yield result if block_given?
      end
    end

    def sh(cmd)
      @logger.info "run '#{cmd}'" if @logger
      Bosh::Exec.sh("#{cmd}", yield: :on_false) do |result|
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

    def generate_agent_env(vm_id, agent_id, networks)
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
      tempfile = Tempfile.new('settings')
      tempfile.write(Yajl::Encoder.encode(env))
      tempfile.close
      tempfile_in = "/tmp/#{Kernel.rand(100_000)}"
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
      tempfile.unlink
    end

    def mount_entry(partition)
      File.read('/proc/mounts').lines.select { |l| l.match(/#{partition}/) }.first
    end

    # Retry the umount for GUARD_RETRIES +1  times
    def umount_guard(mountpoint)
      umount_attempts = UMOUNT_GUARD_RETRIES

      loop do
        return if mount_entry(mountpoint).nil?
        sudo "umount #{mountpoint}" do |result|
          if result.success?
            return
          elsif umount_attempts != 0
            sleep UMOUNT_GUARD_SLEEP
            umount_attempts -= 1
          else
            raise "Failed to umount #{mountpoint}: #{result.output}"
          end
        end
      end
    end

  end

end
