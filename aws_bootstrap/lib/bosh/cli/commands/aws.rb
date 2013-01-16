require "aws-sdk"

module Bosh::Cli::Command
  class AWS < Base

    DEFAULT_CIDR = "10.0.0.0/16"
    OUTPUT_FILE_BASE = "create-vpc-output-%s.yml"

    attr_reader :output_state, :config_dir, :ec2
    attr_accessor :vpc

    def initialize(args=[])
      super(args)
      @output_state = {}
    end

    usage "aws"
    desc  "show bosh aws sub-commands"
    def help
      say("bosh aws sub-commands:")
      nl
      cmds = Bosh::Cli::Config.commands.values.find_all {|c|
        c.usage =~ /^aws/
      }
      Bosh::Cli::Command::Help.list_commands(cmds)
    end

    # TODO use kwalify to validate config file
    usage "aws create vpc"
    desc  "create vpc"
    def create(config_file)
      config = load_yaml(config_file)
      setup_ec2(config["aws"])

      create_vpc(config["vpc"])
      create_subnets(config["vpc"]["subnets"])
      create_dhcp_options(config["vpc"]["dhcp_options"])
      create_security_groups(config["vpc"]["security_groups"])
      allocate_elastic_ips(config["vpc"]["elastic_ips"])
    ensure
      file_path = File.join(File.dirname(config_file), OUTPUT_FILE_BASE % Time.now.strftime("%Y%m%d%H%M%S"))
      flush_output_state(file_path)
      say("details in #{file_path}")
    end

    # TODO best way to get access_key_id & secret_access_key
    usage "aws delete vpc"
    desc  "delete a vpc"
    def delete(output_file)
      config = load_yaml(output_file)
      setup_ec2(config["aws"])

      @vpc = ec2.vpcs[config["vpc"]["id"]]

      err("#{vpc.instances.count} instance(s) running in #{vpc.id} - delete them first") if vpc.instances.count > 0

      dhcp_options = vpc.dhcp_options

      delete_security_groups
      delete_subnets
      delete_vpc
      dhcp_options.delete

      release_elastic_ips(config["elastic_ips"])

      say "deleted VPC and all dependencies".green
    end

    def setup_ec2(params)
      @output_state["aws"] = params.clone
      if params["region"]
        params[:ec2_endpoint] = "ec2.#{params["region"]}.amazonaws.com"
      else
        say("no region specified, defaulting to us-east-1")
      end

      @ec2 = ::AWS::EC2.new(params)
    end

    def create_vpc(options)
      opts = {}
      opts[:instance_tenancy] = options["tenancy"] if options["tenancy"]

      say "creating VPC"

      @vpc = ec2.vpcs.create(options["cidr"] || DEFAULT_CIDR, opts)
      @output_state["vpc"] = {"id" => vpc.id}

      say("\tcreated VPC #{vpc.id}".green)
    end

    def delete_vpc
      vpc.delete
    rescue ::AWS::EC2::Errors::DependencyViolation => e
      err("#{vpc.id} has dependencies that this tool does not delete")
    end

    def create_security_groups(groups)
      say "creating security groups: #{groups.map {|group| group["name"]}.join(", ")}"
      groups.each do |group|
        opts = {}
        opts[:vpc] = vpc.id
        sg = security_group_by_name(group["name"])
        begin
          sg.delete if sg
          sg = vpc.security_groups.create(group["name"])
          group["ingress"].each do |ingress|
            sg.authorize_ingress(ingress["protocol"], ingress["ports"].to_i, ingress["sources"])
          end
          say "\tcreated security group #{group["name"]}".green
        rescue ::AWS::EC2::Errors::DependencyViolation => e
          say("unable to delete security group: #{group['name']}: #{e.message}".yellow)
        end
      end
    end

    def delete_security_groups
      vpc.security_groups.reject{ |group| group.name == "default" }.each(&:delete)
    end

    def create_subnets(subnets)
      say "creating subnets: #{subnets.map{|subnet| subnet["cidr"]}.join(", ")}"
      subnets.each do |subnet|
        options = {}
        options[:availability_zone] = subnet["availability_zone"] if subnet["availability_zone"]
        vpc.subnets.create(subnet["cidr"], options)
        say "\tdone creating subnet: #{subnet["cidr"]}".green
      end
    end

    def delete_subnets
      vpc.subnets.each(&:delete)
    end

    def allocate_elastic_ips(count)
      say "allocating #{count} elastic IP(s)"
      @output_state["elastic_ips"] = []
      count.times do
        eip = ec2.elastic_ips.allocate(vpc: true)
        @output_state["elastic_ips"] << eip.public_ip
        say "\tallocated #{eip.public_ip}".green
      end
    end

    def release_elastic_ips(ips)
      ec2.elastic_ips.each{|ip| ip.release if ips.include? ip.public_ip}
    end

    def create_dhcp_options(options)
      say "creating DHCP options"
      default_dhcp_opts = vpc.dhcp_options

      dhcp_opts = ec2.dhcp_options.create(options)
      dhcp_opts.associate(vpc.id)
      say "\tcreated and associated DHCP options #{dhcp_opts.id}".green

      default_dhcp_opts.delete
    end

    def flush_output_state(file_path)
      File.open(file_path, 'w') {|f| f.write(output_state.to_yaml)}
    end

    private

    def security_group_by_name(name)
      unless @security_groups
        @security_groups = {}
        vpc.security_groups.each do |group|
          @security_groups[group.name] = group
        end
      end
      @security_groups[name]
    end

    def load_yaml(file)
      YAML.load_file file
    rescue
      err("unable to read #{file}".red)
    end
  end
end
