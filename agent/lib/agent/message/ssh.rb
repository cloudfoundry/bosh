module Bosh::Agent
  module Message
    class Ssh < Base
      SSH_USER_PREFIX = "bosh_"
      SSH_USER_BASE_DIR = "/var/vcap/bosh_ssh"

      def self.process(args)
        self.new(args).start
      end

      def initialize(args)
        @command, payload = args
        @params = Yajl::Parser.parse(payload)
      end

      def get_salt_charset
        charset = []
        charset.concat(("a".."z").to_a)
        charset.concat(("A".."Z").to_a)
        charset.concat(("0".."9").to_a)
        charset << "."
        charset << "/"
        charset
      end

      def encrypt_password(plain_text)
        @salt_charset ||= get_salt_charset
        salt = "$6$"
        8.times do |_|
          salt << @salt_charset[rand(@salt_charset.size)]
        end
        plain_text.crypt(salt)
      end

      def shell_cmd(cmd)
        shell_output = %x[#{cmd} 2>&1]
        raise "'#{cmd}' failed, error: #{shell_output}" if $?.exitstatus != 0
      end

      def setup
        begin
          user = @params["user"]
          password = @params["password"]
          logger.info("Setting up ssh for user #{user}")

          shell_cmd(%Q[mkdir -p #{SSH_USER_BASE_DIR}])

          if password
            shell_cmd(%Q[useradd -m -b #{SSH_USER_BASE_DIR} -s /bin/bash -p '#{encrypt_password(password)}' #{user}])
          else
            shell_cmd(%Q[useradd -m -b #{SSH_USER_BASE_DIR} -s /bin/bash #{user}])
          end

          # Add user to admin and vcap group
          shell_cmd(%Q[usermod -G admin,vcap #{user}])

          # Add public key to authorized keys
          ssh_dir = File.join(SSH_USER_BASE_DIR, user, ".ssh")
          FileUtils.mkdir_p(ssh_dir)

          File.open(File.join(ssh_dir, "authorized_keys"), "w+") do |f|
            f.write(@params["public_key"])
          end
          FileUtils.chown_R(user, user, ssh_dir)

          # Start sshd
          SshdMonitor.start_sshd
          {"command" => @command, "status" => "success", "ip" => Bosh::Agent::Config.default_ip}
        rescue => e
          return {"command" => @command, "status" => "failure", "error" => e.message}
        end
      end

      def cleanup
        begin
          return {"command" => @command, "status" => "bad_user"} if @params["user"].nil? &&
                                                                    @params["user_regex"].nil?
          users = []
          user = @params["user"]
          logger.info("Cleaning up ssh user #{user}")
          if user
            users << user
          else
            # list users
            File.open("/etc/passwd", "r") do |f|
              while user_entry = f.gets
                user = /(^.*?):/.match(user_entry)[1]
                if /#{@params["user_regex"]}/ =~ user
                  users << user
                end
              end
            end
          end

          users.each do |user|
            # cant trust the user_regex completely, so skip unexpected users
            next unless user =~ /^#{SSH_USER_PREFIX}/
            logger.info("deleting user #{user}")
            shell_cmd(%Q[userdel -r #{user}])
          end

          # Stop sshd
          SshdMonitor.stop_sshd
          {"command" => @command, "status" => "success"}
        rescue => e
          return {"command" => @command, "status" => "failure", "error" => e.message}
        end
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
