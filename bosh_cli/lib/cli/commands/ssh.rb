require 'cli/job_command_args'

module Bosh::Cli
  module Command
    class Ssh < Base
      SSH_USER_PREFIX = 'bosh_'
      SSH_DSA_PUB     = File.expand_path('~/.ssh/id_dsa.pub')
      SSH_RSA_PUB     = File.expand_path('~/.ssh/id_rsa.pub')

      # bosh ssh
      usage 'ssh'
      desc 'Execute command or start an interactive session'
      option '--public_key FILE', 'Public key'
      option '--gateway_host HOST', 'Gateway host'
      option '--gateway_user USER', 'Gateway user'
      option '--gateway_identity_file FILE', 'Gateway identity file'
      option '--default_password PASSWORD',
             'Use default ssh password (NOT RECOMMENDED)'
      option '--strict_host_key_checking <yes/no>',
             'Can use this flag to skip host key checking (NOT RECOMMENDED)'

      def shell(*args)
        if args.size > 0
          job, index, command = JobCommandArgs.new(args).to_a
        else
          command    = ''
          job, index = prompt_for_job_and_index
        end

        manifest = prepare_deployment_manifest(show_state: true)
        job_must_exist_in_deployment(manifest.hash, job)

        index = valid_index_for(manifest.hash, job, index, integer_index: true)

        if command.empty?
          setup_interactive_shell(manifest.name, job, index)
        else
          say("Executing `#{command.join(' ')}' on #{job}/#{index}")
          perform_operation(:exec, manifest.name, job, index, command)
        end
      end

      # bosh scp
      usage 'scp'
      desc 'upload/download the source file to the given job. ' +
             'Note: for download /path/to/destination is a directory'
      option '--download', 'Download file'
      option '--upload', 'Upload file'
      option '--public_key FILE', 'Public key'
      option '--gateway_host HOST', 'Gateway host'
      option '--gateway_user USER', 'Gateway user'
      option '--gateway_identity_file FILE', 'Gateway identity file'

      def scp(*args)
        job, index, args = JobCommandArgs.new(args).to_a
        upload           = options[:upload]
        download         = options[:download]
        if (upload && download) || (upload.nil? && download.nil?)
          err('Please specify either --upload or --download')
        end

        manifest = prepare_deployment_manifest(show_state: true)
        job_must_exist_in_deployment(manifest.hash, job)

        if args.size != 2
          err('Please enter valid source and destination paths')
        end
        say("Executing file operations on job #{job}")
        perform_operation(upload ? :upload : :download, manifest.name, job, index, args)
      end

      usage 'cleanup ssh'
      desc 'Cleanup SSH artifacts'

      def cleanup(*args)
        job, index, args = JobCommandArgs.new(args).to_a
        if args.size > 0
          err("SSH cleanup doesn't accept any extra args")
        end

        manifest = prepare_deployment_manifest(show_state: true)
        job_must_exist_in_deployment(manifest.hash, job)

        say("Cleaning up ssh artifacts from #{job}/#{index}")
        director.cleanup_ssh(manifest.name, job, "^#{SSH_USER_PREFIX}", [index])
      end

      private

      def get_salt_charset
        charset = []
        charset.concat(('a'..'z').to_a)
        charset.concat(('A'..'Z').to_a)
        charset.concat(('0'..'9').to_a)
        charset << '.'
        charset << '/'
        charset
      end

      def encrypt_password(plain_text)
        return unless plain_text
        @salt_charset ||= get_salt_charset
        salt          = ''
        8.times do
          salt << @salt_charset[rand(@salt_charset.size)]
        end
        plain_text.crypt(salt)
      end

      # @param [String] job
      # @param [Integer] index
      # @param [optional,String] password
      def setup_ssh(deployment_name, job, index, password)
        user            = random_ssh_username

        say("Target deployment is `#{deployment_name}'")
        nl
        say('Setting up ssh artifacts')
        status, task_id = director.setup_ssh(
          deployment_name, job, index, user,
          public_key, encrypt_password(password))

        unless status == :done
          err("Failed to set up SSH: see task #{task_id} log for details")
        end

        sessions = JSON.parse(director.get_task_result_log(task_id))

        unless sessions && sessions.kind_of?(Array) && sessions.size > 0
          err("Error setting up ssh, check task #{task_id} log for more details")
        end

        sessions.each do |session|
          unless session.kind_of?(Hash)
            err("Unexpected SSH session info: #{session.inspect}. " +
                  "Please check task #{task_id} log for more details")
          end
        end

        begin
          if options[:gateway_host]
            require 'net/ssh/gateway'
            gw_host    = options[:gateway_host]
            gw_user    = options[:gateway_user] || ENV['USER']
            gw_options = {}
            gw_options[:keys] = [options[:gateway_identity_file]] if options[:gateway_identity_file]
            begin
              gateway = Net::SSH::Gateway.new(gw_host, gw_user, gw_options)
            rescue Net::SSH::AuthenticationFailed
              err("Authentication failed with gateway #{gw_host} and user #{gw_user}.")
            end
          else
            gateway = nil
          end

          yield sessions, user, gateway
        ensure
          nl
          say('Cleaning up ssh artifacts')
          indices = sessions.map { |session| session['index'] }
          director.cleanup_ssh(deployment_name, job, "^#{user}$", indices)
          gateway.shutdown! if gateway
        end
      end

      def random_ssh_username
        SSH_USER_PREFIX + rand(36**9).to_s(36)
      end

      # @param [String] job Job name
      # @param [Integer] index Job index
      def setup_interactive_shell(deployment_name, job, index)
        password = options[:default_password]

        if password.nil?
          password = ask(
            'Enter password (use it to ' +
              'sudo on remote host): ') { |q| q.echo = '*' }

          err('Please provide ssh password') if password.blank?
        end

        setup_ssh(deployment_name, job, index, password) do |sessions, user, gateway|
          session = sessions.first

          unless session['status'] == 'success' && session['ip']
            err("Failed to set up SSH on #{job}/#{index}: #{session.inspect}")
          end

          say("Starting interactive shell on job #{job}/#{index}")

          skip_strict_host_key_checking = options[:strict_host_key_checking] =~ (/(no|false)$/i) ?
              '-o StrictHostKeyChecking=no' : '-o StrictHostKeyChecking=yes'

          if gateway
            port        = gateway.open(session['ip'], 22)
            ssh_session = Process.spawn('ssh', "#{user}@localhost", '-p', port.to_s, skip_strict_host_key_checking)
            Process.waitpid(ssh_session)
            gateway.close(port)
          else
            ssh_session = Process.spawn('ssh', "#{user}@#{session['ip']}", skip_strict_host_key_checking)
            Process.waitpid(ssh_session)
          end
        end
      end

      def perform_operation(operation, deployment_name, job, index, args)
        setup_ssh(deployment_name, job, index, options[:default_password]) do |sessions, user, gateway|
          sessions.each do |session|
            unless session['status'] == 'success' && session['ip']
              err("Failed to set up SSH on #{job}/#{index}: #{session.inspect}")
            end

            with_ssh(user, session['ip'], gateway) do |ssh|
              case operation
                when :exec
                  nl
                  say("#{job}/#{session['index']}")
                  say(ssh.exec!(args.join(' ')))
                when :upload
                  ssh.scp.upload!(args[0], args[1])
                when :download
                  file = File.basename(args[0])
                  path = "#{args[1]}/#{file}.#{job}.#{session['index']}"
                  ssh.scp.download!(args[0], path)
                  say("Downloaded file to #{path}".make_green)
                else
                  err("Unknown operation #{operation}")
              end
            end
          end
        end
      end

      # @return [String] Public key
      def public_key
        public_key_path = options[:public_key]

        if public_key_path
          unless File.file?(public_key_path)
            err("Can't find file `#{public_key_path}'")
          end
          return File.read(public_key_path)
        else
          %x[ssh-add -L 1>/dev/null 2>&1]
          if $?.exitstatus == 0
            return %x[ssh-add -L].split("\n").first
          else
            [SSH_DSA_PUB, SSH_RSA_PUB].each do |key_file|
              return File.read(key_file) if File.file?(key_file)
            end
          end
        end

        err('Please specify a public key file')
      end

      # @param [String] user
      # @param [String] ip
      # @param [optional, Net::SSH::Gateway] gateway
      # @yield [Net::SSH]
      def with_ssh(user, ip, gateway = nil)
        require 'net/scp'
        if gateway
          gateway.ssh(ip, user) { |ssh| yield ssh }
        else
          require 'net/ssh'
          Net::SSH.start(ip, user) { |ssh| yield ssh }
        end
      end
    end
  end
end
