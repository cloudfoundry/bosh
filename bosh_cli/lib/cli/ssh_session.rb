require 'sshkey'

module Bosh::Cli
  class SSHSession

    attr_reader :public_key

    def initialize
      @session_uuid = SecureRandom::uuid
      @public_key = generate_rsa_key
    end

    def set_host_session(session)
      @host_session = session
    end

    def ssh_known_host_option(port)
      user_known_host_option(port)
    end

    def ssh_private_key_option
      private_key_file_name = File.join(ENV['HOME'], '.bosh', 'tmp', "#{@session_uuid}_key")
      "-i#{private_key_file_name}"
    end

    def cleanup
      remove_private_key
      remove_known_host_file
    end

    private

    def generate_rsa_key
      key = SSHKey.generate(
          type:       "RSA",
          bits:       2048,
          comment:    "bosh-ssh",
      )
      add_private_key(key.private_key)
      return key.ssh_public_key
    end

    def remove_private_key
      file_name = private_key_file_name
      FileUtils.rm_rf(file_name) if File.exist?(file_name)
    end

    def private_key_file_name
      File.join(ENV['HOME'], '.bosh', 'tmp', "#{@session_uuid}_key")
    end

    def add_private_key(private_key)
      file_name = private_key_file_name
      create_dir_for_file(file_name)

      key_File = File.new(file_name, "w", 0400)
      key_File.puts(private_key)
      key_File.close
    end


    def user_known_host_option(gatewayPort)
      if @host_session.include?('host_public_key')
        hostEntryIP =  if gatewayPort then "[localhost]:#{gatewayPort}" else @host_session['ip'] end
        hostEntry = "#{hostEntryIP} #{@host_session['host_public_key']}"
        add_known_host_file(hostEntry)

        return "-o UserKnownHostsFile=#{known_host_file_path}"
      else
        return String.new
      end
    end

    def known_host_file_path
      File.join(ENV['HOME'], '.bosh', 'tmp', "#{@session_uuid}_known_hosts")
    end

    def add_known_host_file(hostEntry)
      file_name = known_host_file_path

      create_dir_for_file(file_name)

      known_host_file = File.new(file_name, "w")
      known_host_file.puts(hostEntry)
      known_host_file.close
    end

    def remove_known_host_file
      file_name = known_host_file_path
      FileUtils.rm_rf(file_name) if File.exist?(file_name)
    end

    def create_dir_for_file(file_name)
      dirname = File.dirname(file_name)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end
    end
  end
end