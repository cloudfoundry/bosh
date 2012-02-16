module Bosh::Cli::Command
  class Ssh < Base
    include Bosh::Cli::DeploymentHelper
    CMD_UPLOAD = "upload"
    CMD_DOWNLOAD = "download"
    CMD_EXEC = "exec"
    SSH_USER_PREFIX = "bosh_"
    SSH_DEFAULT_PASSWORD = "bosh"
    SSH_DSA_PUB = File.expand_path("~/.ssh/id_dsa.pub")
    SSH_RSA_PUB = File.expand_path("~/.ssh/id_rsa.pub")

    def parse_options(args)
      options = {}
      ["public_key", "gateway_host", "gateway_user", "index", "job"].each do |option|
        pos = args.index("--#{option}")
        if pos
          options[option] = args[pos + 1]
          args.delete_at(pos + 1)
          args.delete_at(pos)
        end
      end
      if index = options["index"]
        valid_index = Integer(index) rescue nil
        err "Please specify a valid job index: #{index} is invalid" unless valid_index
      end
      options
    end

    def get_public_key(options)
      # Get public key
      public_key = nil
      if options["public_key"]
        err("Please specify a valid public key file") unless File.file?(options["public_key"])
        public_key = File.read(options["public_key"])
      else
        # See if ssh-add can be used
        result = execute("ssh-add -L")
        unless result.failed?
          # it only picks the first key
          # TODO make it configurable or ask which to use if there are multiple
          public_key = result.stdout.first.split("\n").first
        else
          # Pick up public key from home dir
          [SSH_DSA_PUB, SSH_RSA_PUB].each do |key_file|
            if File.file?(key_file)
              public_key = File.read(key_file)
              break
            end
          end
        end
      end
      err("Please specify a public key file") if public_key.nil?
      public_key
    end

    def setup_ssh(job, index, password, options, &block)
      # Get public key
      public_key = get_public_key(options)

      # Generate a random user name
      user = SSH_USER_PREFIX + rand(36**9).to_s(36)

      # Get deployment name
      manifest_name = prepare_deployment_manifest["name"]

      say "Target deployment is #{manifest_name}"
      results = director.setup_ssh(manifest_name, job, index, user, public_key, password)
      if results.nil?
        err "Error setting up ssh"
      end

      yield(results, user) if block
    ensure
      if results
        say "Cleaning up ssh artifacts"
        indexes = results.map {|result| result["index"]}
        # Cleanup only this one 'user'
        director.cleanup_ssh(manifest_name, job, "^#{user}$", indexes)
      end
    end

    def get_free_port
      socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      socket.bind(Addrinfo.tcp("127.0.0.1", 0))
      port = socket.local_address.ip_port
      socket.close

      # The port could get used in the interim, but unlikely in real life
      port
    end

    def setup_interactive_shell(job, password, options)
      index = options["index"]
      err "Please specify a job index" if index.nil?

      if password.nil?
        password_retries = 0
        while password.blank? && password_retries < 3
          password = ask("Enter password (use it to sudo on remote host): ") { |q| q.echo = "*" }
          password_retries += 1
        end
        err("Please provide ssh password") if password.blank?
      end

      setup_ssh(job, index, password, options) do |results, user|
        result = results.first
        if result["status"] != "success" || result["ip"].nil?
          err "Failed to setup ssh on index #{result["index"]}, error: #{result["error"]}"
        end

        say "Starting interactive shell on job #{job}, index #{index}"
        # Start interactive session
        if options["gateway_host"]
          local_port = get_free_port
          say("Connecting to local port #{local_port}")
          # Create the ssh tunnel
          fork {
            gateway = (options["gateway_user"] ? "#{options["gateway_user"]}@" : "") + options["gateway_host"]
            # Tunnel will close after 30 seconds, so no need to worry about cleaning it up
            exec("ssh -f -L#{local_port}:#{result["ip"]}:22 #{gateway} sleep 30")
          }
          result["ip"] = "localhost -p #{local_port}"
          # Wait for tunnel to get established
          sleep 3
        end
        p = fork {
          exec("ssh #{user}@#{result["ip"]}")
        }
        Process.waitpid(p)
      end
    end

    def shell(*args)
      job = args.shift
      password = args.delete("--default_password") && SSH_DEFAULT_PASSWORD
      options = parse_options(args)

      if args.size == 0
        setup_interactive_shell(job, password, options)
      else
        say "Executing command '#{args.join(" ")}' on job #{job}"
        execute_command(CMD_EXEC, job, options, args)
      end
    end

    def with_ssh(gateway, ip, user, &block)
      if gateway
        gateway.ssh(ip, user) do |ssh|
          yield(ssh)
        end
      else
        Net::SSH.start(ip, user) do |ssh|
          yield(ssh)
        end
      end
    end

    def with_gateway(host, user, &block)
      gateway = Net::SSH::Gateway.new(host, user || ENV['USER']) if host
      yield(gateway ||= nil)
    ensure
      gateway.shutdown! if gateway
    end

    def execute_command(command, job, options, args)
      setup_ssh(job, options["index"], nil, options) do |results, user|
        with_gateway(options["gateway_host"], options["gateway_user"]) do |gateway|
          results.each do | result|
            err "Failed to setup ssh on index #{result["index"]}, error: #{result["error"]}" if result["status"] != "success"
            with_ssh(gateway, result["ip"], user) do |ssh|
              case command
              when CMD_EXEC
                say "\nJob #{job} index #{result["index"]}"
                puts ssh.exec!(args.join(" "))
              when CMD_UPLOAD
                ssh.scp.upload!(args[0], args[1])
              when CMD_DOWNLOAD
                file = File.basename(args[0])
                path = "#{args[1]}/#{file}.#{job}.#{result["index"]}"
                ssh.scp.download!(args[0], path)
              end
            end
          end
        end
      end
    end

    def scp(*args)
      job = args.shift
      options = parse_options(args)
      upload = args.delete("--upload")
      download = args.delete("--download")
      if upload.nil? && download.nil?
        err "Please specify one of --upload or --download"
      end
      err "Please enter valid source and destination paths" if args.empty? || args.size < 2
      say "Executing file operations on job #{job}"
      execute_command(upload ? CMD_UPLOAD : CMD_DOWNLOAD, job, options, args)
    end

    def cleanup(*args)
      options = parse_options(args)
      manifest_name = prepare_deployment_manifest["name"]
      results = nil
      if options["index"]
        results = []
        results << {"index" => options["index"]}
      end
      say "Cleaning up ssh artifacts from job #{options["job"]}, index #{options["index"]}"
      director.cleanup_ssh(manifest_name, options["job"], "^#{SSH_USER_PREFIX}", [options["index"]])
    end
  end
end
