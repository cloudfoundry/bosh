require "aws-sdk"

module Bosh::Cli::Command
  class AWS < Base

    DEFAULT_CIDR = "10.0.0.0/16"
    OUTPUT_FILE = "create-vpc-output.yml"

    attr_reader :output_state, :config_dir
    attr_accessor :vpc

    # TODO use kwalify to validate config file
    usage "aws create vpc"
    desc  "create vpc"
    def create(config_file)
      config = YAML.load_file(config_file)
      @config_dir = File.dirname(config_file)
      setup_ec2(config["aws"])

      create_vpc(config["vpc"])

      create_subnets(config["vpc"]["subnets"])
      create_dhcp_options(config["vpc"]["dhcp_options"])
      create_security_groups(config["vpc"]["security_groups"])
      allocate_elastic_ips(config["vpc"]["elastic_ips"])
    end

    # TODO best way to get access_key_id & secret_access_key
    usage "aws destroy vpc"
    desc  "destroy vpc"
    def destroy(output_file)
      config = YAML.load_file(output_file)
      setup_ec2(config["aws"])

      # make sure there are no instances in the vpc
      # destroy dhcp_options
      # destroy subnets
      # destroy security_groups
      # release eips
      #
    end

    def setup_ec2(params)
      @output_state = {}
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
      @vpc = @ec2.vpcs.create(options["cidr"] || DEFAULT_CIDR, opts)
      @output_state["vpc"] = {"id" => @vpc.id}
      say("created VPC #{@vpc.id}")
      flush_output_state
    end

    def create_security_groups(groups)
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
        rescue ::AWS::EC2::Errors::DependencyViolation => e
          say("unable to delete security group: #{group['name']}: #{e.message}")
        end
      end
    end

    def create_subnets(subnets)
      subnets.each do |subnet|
        options = {}
        options[:availability_zone] = subnet["availability_zone"] if subnet["availability_zone"]
        vpc.subnets.create(subnet["cidr"], options)
      end
    end

    def allocate_elastic_ips(count)
      @output_state["elastic_ips"] = []
      count.times do
        eip = @ec2.elastic_ips.allocate(:vpc => true)
        @output_state["elastic_ips"] << eip.public_ip
      end
    ensure
      flush_output_state
    end

    def create_dhcp_options(options)
      dhcp_opts = @ec2.dhcp_options.create(options)
      dhcp_opts.associate(vpc.id)
    end

    def flush_output_state
      output_file = File.join(config_dir, OUTPUT_FILE)
      File.open(output_file, 'w') {|f| f.write(output_state.to_yaml)}
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

  end
end
