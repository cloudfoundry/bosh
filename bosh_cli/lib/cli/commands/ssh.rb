require 'cli/job_command_args'
require 'cli/ssh_session'

module Bosh::Cli
  module Command
    class Ssh < Base

      # bosh ssh
      usage 'ssh'
      desc 'Execute command or start an interactive session'
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

        say("Target deployment is `#{deployment_name}'")
        nl
        say('Setting up ssh artifacts')

        ssh_session = SSHSession.new

        status, task_id = director.setup_ssh(
          deployment_name, job, index, ssh_session.user,
          ssh_session.public_key, encrypt_password(password))

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

        ssh_session.set_host_session(sessions.first)

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

          yield sessions, gateway, ssh_session
        ensure
          nl
          say('Cleaning up ssh artifacts')
          ssh_session.cleanup
          indices = sessions.map { |session| session['index'] }
          director.cleanup_ssh(deployment_name, job, "^#{ssh_session.user}$", indices)
          gateway.shutdown! if gateway
        end
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

        setup_ssh(deployment_name, job, index, password) do |sessions, gateway, ssh_session|
          session = sessions.first

          unless session['status'] == 'success' && session['ip']
            err("Failed to set up SSH on #{job}/#{index}: #{session.inspect}")
          end

          say("Starting interactive shell on job #{job}/#{index}")

          skip_strict_host_key_checking = options[:strict_host_key_checking] =~ (/(no|false)$/i) ?
              '-o StrictHostKeyChecking=no' : '-o StrictHostKeyChecking=yes'

          private_key_option = ssh_session.ssh_private_key_option

          if gateway
            port        = gateway.open(session['ip'], 22)
            known_host_option  = ssh_session.ssh_known_host_option(port)
            ssh_session_pid = Process.spawn('ssh', "#{ssh_session.user}@localhost", '-p', port.to_s, private_key_option, skip_strict_host_key_checking, known_host_option)
            Process.waitpid(ssh_session_pid)
            gateway.close(port)
          else
            known_host_option = ssh_session.ssh_known_host_option(nil)
            ssh_session_pid = Process.spawn('ssh', "#{ssh_session.user}@#{session['ip']}", private_key_option, skip_strict_host_key_checking, known_host_option)
            Process.waitpid(ssh_session_pid)
          end
        end
      end

      def perform_operation(operation, deployment_name, job, index, args)
        setup_ssh(deployment_name, job, index, options[:default_password]) do |sessions, gateway, ssh_session|
          sessions.each do |session|
            unless session['status'] == 'success' && session['ip']
              err("Failed to set up SSH on #{job}/#{index}: #{session.inspect}")
            end

            with_ssh(session['ip'], ssh_session, gateway) do |ssh|
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

      # @param [String] user
      # @param [String] ip
      # @param [optional, Net::SSH::Gateway] gateway
      # @yield [Net::SSH]
      def with_ssh(ip, ssh_session, gateway = nil)
        require 'net/scp'
        options = { :keys => ssh_session.ssh_private_key_path }
        if gateway
          gateway.ssh(ip, ssh_session.user, options) { |ssh| yield ssh }
        else
          require 'net/ssh'

          known_host_path = ssh_session.ssh_known_host_path(nil)
          if known_host_path.length > 0
            options[:user_known_hosts_file] = known_host_path
          end

          Net::SSH.start(ip, ssh_session.user, options) { |ssh| yield ssh }
        end
      end
    end
  end
end
