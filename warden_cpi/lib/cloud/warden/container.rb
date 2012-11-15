
module Bosh::WardenCloud

  class Container

    def initialize(id, warden_sock_path)
      @id = id
      @warden_sock_path = warden_sock_path
    end

    def create_device(device_num)
      device_path = find_available_device
      status = run("mknod #{device_path} b 7 #{device_num}")
      if status != 0
        raise Bosh::Clouds::CloudError, "Creating device #{device_path} failed"
      end
      device_path
    end

    def delete_device(device_path)
      run("umount #{device_path}")
      run("rm -f #{device_path}")
    end

    def exist?
      warden_client = setup_warden_client
      warden_client.connect

      req = Warden::Protocol::InfoRequest.new
      req.handle = @id

      result = true
      begin
        warden_client.call(req)
      rescue
        result = false
      ensure
        warden_client.disconnect
      end

      result
    end

    private

    def find_available_device
      "bcedfghigklmnopqrstuvwxyz".each_char do |c|
        device = "/dev/sd#{c}"
        status = run(@id, "ls #{device}")
        return device if status != 0
      end

      raise Bosh::Clouds::CloudError, "No available device in container #{@id}"
    end

    def run(cmd)
      warden_client = setup_warden_client
      warden_client.connect

      req = Warden::Protocol::RunRequest.new
      req.handle = @id
      req.script = cmd
      req.privileged = true

      rsp = warden_client.call( req )
      warden_client.disconnect

      rsp.exit_status
    end

    def setup_warden_client
      Warden::Client.new(@warden_sock_path)
    end
  end
end
