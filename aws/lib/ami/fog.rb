require 'fog'
require 'yaml'

module Bosh::Ami
  class Fog

    BOOTSTRAP_OPTIONS = {
        :flavor_id => 'm1.small', # 64 bit, normal medium
        :bits => 64,
        :username => 'ubuntu'
    }

    BOSH_SG = "bosh"
    ANY = {:cidr_ip => '0.0.0.0/0'}

    AWS_OPTIONS = {
        :provider => "AWS"
    }

    def initialize(config)
      @config = config
      @hosts = @config[:regions]

      @bootstrap = BOOTSTRAP_OPTIONS.dup
      @bootstrap[:public_key_path] = @config[:ssh][:public]
      @bootstrap[:private_key_path] = @config[:ssh][:private]

      @aws_options = AWS_OPTIONS.dup
      @aws_options[:aws_access_key_id] = @config[:aws][:access_key_id]
      @aws_options[:aws_secret_access_key] = @config[:aws][:secret_access_key]
    end

    def loop(regions)
      regions.each do |region|
        puts region
        connect(region)
        add_bosh_sg unless has_bosh_sg?
        server = create(region)
        yield(region, server)
      end
    end

    # connects to a region
    def connect(region)
      options = @aws_options.dup
      options[:region] = region
      @fog = ::Fog::Compute.new(options)
    end

    def has_bosh_sg?
      @fog.security_groups.find { |sg| sg.name == BOSH_SG }
    end

    # adds a new security group called "bosh"
    def add_bosh_sg
      sg = @fog.security_groups.new(:name => BOSH_SG, :description => BOSH_SG)
      sg.save
      sg.authorize_port_range(22..22, ANY)
      sg.authorize_port_range(6868..6868, ANY) # agent http interface
      sg.authorize_port_range(25555..25555, ANY)
    end

    # creates a new server for the region, unless a server already exist
    # @return [Fog::Server] the server
    def create(region)
      if @hosts[region]
        server = @fog.servers.get(@hosts[region][:id])
        if server
          puts("  using instance #{server.id}")
          return server
        end
      end

      printf("  creating instance ")
      # until https://github.com/fog/fog/pull/1095 is in a released version
      # we need to monkey patch the default ami selection
      @bootstrap[:image_id] = "ami-d0429ccd" if region == "sa-east-1"
      @bootstrap[:groups] = [BOSH_SG]

      server = @fog.servers.bootstrap(@bootstrap)
      @hosts[region] = {
          :id => server.id,
          :name => server.dns_name
      }

      puts server.id
      server
    rescue Excon::Errors::Timeout => e
      puts "  failed to create instance: #{e.message}"
      @hosts[region] = {}
      nil
    end

  end
end