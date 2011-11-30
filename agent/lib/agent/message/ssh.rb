module Bosh::Agent
  module Message
    class Ssh < Base
      SSH_USER_PREFIX = "bosh_"

      def self.process(args)
        self.new(args).start
      end

      def initialize(args)
        @command, payload = args
        @params = Yajl::Parser.parse(payload)
      end

      def default_ip
        state = Bosh::Agent::Config.state.to_hash
        ip = nil
        state["networks"].each do |k, v|
          ip = v["ip"] if ip.nil?
          if v.key?('default')
            ip = v["ip"]
          end
        end
        ip
      end

      def setup
        user = @params["user"]
        password = @params["password"]
        logger.info("Setting up ssh for user #{user}")
        if password
          IO.popen("adduser --gecos \"bssh,,,,,\" #{user}", "r+") do |f|
            f.puts(password)
            f.puts(password)
            f.close_write
            while f.gets
            end
          end
        else
          %x[adduser --disabled-password --gecos "bssh,,,,," #{user}]
        end

        # Add user to admin and vcap group
        %x[usermod -G admin,vcap #{user}]

        # Add public key to authorized keys
        ssh_dir = File.join("/home", user, ".ssh")
        FileUtils.mkdir_p(ssh_dir)

        File.open(File.join(ssh_dir, "authorized_keys"), "w+") do |f|
          f.write(@params["public_key"])
        end
        FileUtils.chown_R(user, user, ssh_dir)

        # Start sshd
        SshdMonitor.start_sshd
        {"command" => @command, "status" => "success", "ip" => default_ip}
      end

      def cleanup
        return {"command" => @command, "status" => "bad_user"} if @params["user"].nil? &&
                                                                  @params["user_regex"].nil?
        users = []
        user = @params["user"]
        logger.info("Cleaning up ssh user #{user}")
        if user
          users << user
        else
          users = %x[cut -d ":" -f 1 /etc/passwd | grep "#{@params["user_regex"]}"].split("\n")
        end

        users.each do |user|
          next unless user =~ /^#{SSH_USER_PREFIX}/
          logger.info("deleting user #{user}")
          %x[deluser --remove-home #{user}]
        end

        # Stop sshd
        SshdMonitor.stop_sshd

        {"command" => @command, "status" => "success"}
      end

      def start
        case @command
        when "setup"
          setup
        when "cleanup"
          cleanup
        end
      end
    end
  end
end
