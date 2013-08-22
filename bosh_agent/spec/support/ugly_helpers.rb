module Bosh::Agent
  module Spec
    module UglyHelpers
      def setup_directories
        tmpdir = Dir.mktmpdir
        base_dir = File.join(tmpdir, 'bosh')
        sys_root = File.join(tmpdir, 'system_root')

        FileUtils.mkdir_p(base_dir)
        FileUtils.mkdir_p(File.join(base_dir, 'packages'))
        FileUtils.mkdir_p(sys_root)

        Bosh::Agent::Config.system_root = sys_root
        Bosh::Agent::Config.base_dir = base_dir
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def get_free_port
        socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        socket.bind(Addrinfo.tcp('127.0.0.1', 0))
        port = socket.local_address.ip_port
        socket.close
        # race condition, but good enough for now
        port
      end
    end
  end
end
