# Copyright (c) 2009-2012 VMware, Inc.

require 'fileutils'

module Bosh::Agent
  module Message
    class Ssh < Base
      SSH_USER_PREFIX = "bosh_"

      def self.process(args)
        ssh = self.new(args)
        case ssh.command
          when "setup"
            ssh.setup
          when "cleanup"
            ssh.cleanup
        end
      end

      def base_dir
        Bosh::Agent::Config.base_dir
      end

      def ssh_base_dir
        File.join(base_dir, "bosh_ssh")
      end

      attr_reader :command
      attr_reader :passwd_file
      attr_reader :sudoers_dir

      def initialize(args, options={})
        @command, @params = args
        @passwd_file = options.fetch(:passwd_file, '/etc/passwd')
        @sudoers_dir = options.fetch(:sudoers_dir, '/etc/sudoers.d')
        @command_runner = options.fetch(:command_runner, Bosh::Exec)
      end

      def setup
        begin
          user = @params["user"]
          password = @params["password"]
          logger.info("Setting up ssh for user #{user}")

          shell_cmd(%Q[mkdir -p #{ssh_base_dir}])

          if password
            shell_cmd(%Q[useradd -m -b #{ssh_base_dir} -s /bin/bash -p '#{password}' #{user}])
          else
            shell_cmd(%Q[useradd -m -b #{ssh_base_dir} -s /bin/bash #{user}])
          end

          grant_nopass_sudo user

          # Add user to admin and vcap group
          shell_cmd(%Q[usermod -G admin,vcap #{user}])

          # Add public key to authorized keys
          ssh_dir = File.join(ssh_base_dir, user, ".ssh")
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
          return {"command" => @command, "status" => "bad_user"} if @params["user_regex"].nil?

          # CLI calls this function under the following 2 scenarios
          # 1. When it wants to cleanup a single user after an interactive
          #    session or after executing a remote command. In this case
          #    the "user_regex" would match a single user i.e. "^user_name$"
          # 2. CLI has a special option called "cleanup all ssh users", in this
          #    case the "user_regex" is more generic like "^user_name_prefix"
          #
          # Irrespecitve of the scenarios above, we dont fully trust the "user_regex"
          # and will cull the list of users to those that match SSH_USER_PREFEX

          users = []
          # list users
          File.open(passwd_file) do |f|
            while user_entry = f.gets
              next unless user_match = /(^.*?):/.match(user_entry)
              user = user_match[1]
              if /#{@params["user_regex"]}/ =~ user
                users << user
              end
            end
          end

          users.each do |user|
            # cant trust the user_regex completely, so skip unexpected users
            next unless user =~ /^#{SSH_USER_PREFIX}/
            logger.info("deleting user #{user}")
            shell_cmd(%Q[userdel -r #{user}])

            revoke_nopass_sudo user
          end

          # Stop sshd. Note, SshdMonitor handles the race between stopping sshd
          # when multiple users are logged in, so we dont have to do any
          # specific checks here.
          SshdMonitor.stop_sshd
          {"command" => @command, "status" => "success"}
        rescue => e
          return {"command" => @command, "status" => "failure", "error" => e.message}
        end
      end

      private

      def shell_cmd(cmd)
        @command_runner.sh cmd
      end

      def grant_nopass_sudo(user)
        open(sudoers_file(user), 'a') do |f|
          f.write("\n#{user} ALL=(ALL) NOPASSWD:ALL\n")
          f.chmod(0440)
        end
      end

      def revoke_nopass_sudo(user)
        FileUtils.rm_f(sudoers_file(user))
      end

      def sudoers_file(user)
        File.join(sudoers_dir, user)
      end

    end
  end
end
