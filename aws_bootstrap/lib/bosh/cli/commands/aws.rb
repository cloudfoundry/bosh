require_relative '../../../bosh_aws_bootstrap/vpc'
require_relative '../../../bosh_aws_bootstrap/ec2'
require_relative '../../../bosh_aws_bootstrap/s3'

module Bosh::Cli::Command
  class AWS < Base
    DEFAULT_CIDR = "10.0.0.0/16" # KILL
    OUTPUT_FILE_BASE = "create-vpc-output-%s.yml"

    attr_reader :output_state, :config_dir, :ec2
    attr_accessor :vpc

    def initialize(args=[])
      super(args)
      @output_state = {}
    end

    usage "aws"
    desc "show bosh aws sub-commands"

    def help
      say "bosh aws sub-commands:\n"
      commands = Bosh::Cli::Config.commands.values.find_all { |command| command.usage =~ /^aws/ }
      Bosh::Cli::Command::Help.list_commands(commands)
    end

    usage "aws create vpc"
    desc "create vpc"

    def create_vpc(config_file)
      config = load_yaml(config_file)

      ec2 = Bosh::Aws::EC2.new(config["aws"])
      @output_state["aws"] = config["aws"]

      vpc = Bosh::Aws::VPC.create(ec2, config["vpc"]["cidr"], config["vpc"]["instance_tenancy"])
      @output_state["vpc"] = {"id" => vpc.vpc_id}

      subnets = config["vpc"]["subnets"]
      say "creating subnets: #{subnets.map { |subnet| subnet["cidr"] }.join(", ")}"
      vpc.create_subnets(subnets)

      dhcp_options = config["vpc"]["dhcp_options"]
      say "creating DHCP options"
      vpc.create_dhcp_options(dhcp_options)

      security_groups = config["vpc"]["security_groups"]
      say "creating security groups: #{security_groups.map { |group| group["name"] }.join(", ")}"
      vpc.create_security_groups(security_groups)

      count = config["vpc"]["elastic_ips"]
      say "allocating #{count} elastic IP(s)"
      ec2.allocate_elastic_ips(count)
      @output_state["elastic_ips"] = ec2.elastic_ips
    ensure
      file_path = File.join(File.dirname(config_file), OUTPUT_FILE_BASE % Time.now.strftime("%Y%m%d%H%M%S"))
      flush_output_state file_path

      say "details in #{file_path}"
    end

    usage "aws delete vpc"
    desc "delete a vpc"

    def delete_vpc(details_file)
      details = load_yaml details_file

      ec2 = Bosh::Aws::EC2.new(details["aws"])
      vpc = Bosh::Aws::VPC.find(ec2, details["vpc"]["id"])

      err("#{vpc.instances_count} instance(s) running in #{vpc.vpc_id} - delete them first") if vpc.instances_count > 0

      dhcp_options = vpc.dhcp_options

      vpc.delete_security_groups
      vpc.delete_subnets
      vpc.delete_vpc
      dhcp_options.delete
      ec2.release_elastic_ips details["elastic_ips"]

      say "deleted VPC and all dependencies".green
    end

    usage "aws empty s3"
    desc "empty and delete all s3 buckets"

    def empty_s3(config_file)
      config = load_yaml config_file

      s3 = Bosh::Aws::S3.new(config["aws"])

      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Buckets:\n\t#{s3.bucket_names.join("\n\t")}")

      s3.empty if agree("Are you sure you want to empty and delete all buckets?")
    end

    private

    def flush_output_state(file_path)
      File.open(file_path, 'w') { |f| f.write output_state.to_yaml }
    end

    def load_yaml(file)
      YAML.load_file file
    rescue
      err "unable to read #{file}".red
    end
  end
end
