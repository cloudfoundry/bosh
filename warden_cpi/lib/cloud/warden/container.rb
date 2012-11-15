
module Bosh::WardenCloud

  class Container

    def initialize(id, warden_client)
      @id = id
      @warden_client = warden_client
    end

    def create_device(device_num)
      device_path = find_available_device
      run("mknod #{device_path} b 7 #{device_num}")
      device_path
    end

    def delete_device(device_path)
      begin
        run("umount #{device_path}")
      rescue
        # ignore the result
      end
      run("rm -f #{device_path}")
    end

    def exist?
      @warden_client.connect
      req = Warden::Protocol::InfoRequest.new
      req.handle = @id
      result = true
      begin
        warden_client.call(req)
      rescue
        result = false
      ensure
        @warden_client.disconnect
      end
      result
    end

    private

    def find_available_device
      “bcedfghigklmnopqrstuvwxyz”.each_char do |c|
        device = "/dev/sd#{c}"
        status = run(@id, "ls #{device}")
        return device if status == 0
      end
      raise Bosh::Clouds::CloudError, "No available device in container #{@id}"
    end

    def run(cmd)
      @warden_client.connect
      req = Warden::Protocol::RunRequest.new
      req.handle = @id
      req.script = cmd
      req.privileged = true
      rsp = @warden_client.call( req )
      @warden_client.disconnect

      if rsp.exit_status != 0
        raise Bosh::Clouds::CloudError, rsp.message
      end
    end
  end
end
