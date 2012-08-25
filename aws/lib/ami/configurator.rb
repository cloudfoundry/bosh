module Bosh::Ami
  class Configurator

    def initialize(config, server)
      @config = config
      @server = server
    end

    # configures the server:
    # scp:s files to it and then invokes scripts to set it up and create the AMIs
    def configure(region)
      copy_files
      ssh('$HOME/prepare.sh')
      ssh('$HOME/rbenv.sh')
      ssh('$HOME/gems.sh')
      ssh('$HOME/stemcell.sh')
      ami = ssh("$HOME/ami.rb #{region} #{@config[:aws][:access_key_id]} #{@config[:aws][:secret_access_key]}")
      match = ami.match(/^(ami-[0-9a-f]{8})/)
      if match
        ami = match[0]
        puts "  #{ami}"
        @config[:regions][region][:ami] = ami
      else
        puts "could detect an AMI!"
        @config[:regions][region][:ami] = nil
      end
    end

    def ssh(command)
      puts("  running #{command}")
      result = @server.ssh(command).first
      unless result.status == 0
        puts "  command failed:"
        puts result.stdout
        exit(1)
      end
      result.stdout
    end

    def copy_files
      puts("  copying files...")
      @server.scp("scripts/prepare.sh", "prepare.sh")
      @server.scp("scripts/rbenv.sh", "rbenv.sh")
      @server.scp("scripts/gems.sh", "gems.sh")
      @server.scp("scripts/stemcell-copy.sh", "stemcell-copy")
      @server.scp("scripts/stemcell.sh", "stemcell.sh")
      @server.scp("scripts/ami.rb", "ami.rb")
    end

  end
end