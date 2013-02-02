require_relative "../../../bosh_aws_bootstrap"

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

    usage "aws snapshot deployments"
    desc "snapshot all EBS volumes in all deployments"
    def snapshot_deployments(config_file)
      auth_required
      config = load_yaml(config_file)

      say("Creating snapshots for director `#{target_name}'")
      ec2 = Bosh::Aws::EC2.new(config["aws"])

      deployments = director.list_deployments.map { |d| d["name"] }
      deployments.each do |deployment|
        say("  deployment: `#{deployment}'")
        vms = director.list_vms(deployment)
        instances = ec2.instances_for_ids(vms.map { |vm| vm["cid"] })
        vms.each do |vm|
          instance_id = vm["cid"]
          instance = instances[instance_id]
          unless instance.exists?
            say("    ERROR: instance `#{instance_id}' not found on EC2")
          else
            say("    instance: `#{instance_id}'")
            instance.block_device_mappings.each do |device_path, attachment|
              say("      volume: `#{attachment.volume.id}' device: `#{device_path}'")
              device_name = device_path.match("/dev/(.*)")[1]
              snapshot_name = [deployment, vm['job'], vm['index'], device_name].join('/')
              vm_metadata = JSON.unparse(vm)
              tags = {
                  "device" => device_path,
                  "bosh_data" => vm_metadata,
                  "director_uri" => target_url,
                  "director_uuid" => director.uuid
              }
              ec2.snapshot_volume(attachment.volume, snapshot_name, vm_metadata, tags)
            end
          end
        end
      end
    end

    usage "aws create vpc"
    desc "create vpc"
    def create_vpc(config_file)
      config = load_yaml(config_file)

      ec2 = Bosh::Aws::EC2.new(config["aws"])
      @output_state["aws"] = config["aws"]

      vpc = Bosh::Aws::VPC.create(ec2, config["vpc"]["cidr"], config["vpc"]["instance_tenancy"])
      @output_state["vpc"] = {"id" => vpc.vpc_id, "domain" => config["vpc"]["domain"]}

      subnets = config["vpc"]["subnets"]
      say "creating subnets: #{subnets.map { |subnet| subnet["cidr"] }.join(", ")}"
      vpc.create_subnets(subnets)

      dhcp_options = config["vpc"]["dhcp_options"]
      say "creating DHCP options"
      vpc.create_dhcp_options(dhcp_options)

      security_groups = config["vpc"]["security_groups"]
      say "creating security groups: #{security_groups.map { |group| group["name"] }.join(", ")}"
      vpc.create_security_groups(security_groups)

      count = config["elastic_ips"].values.reduce(0) { |total,job| total += job["instances"] }
      say "allocating #{count} elastic IP(s)"
      ec2.allocate_elastic_ips(count)

      elastic_ips = ec2.elastic_ips
      route53 = Bosh::Aws::Route53.new(config["aws"])

      config["elastic_ips"].each do |name, job|
        @output_state["elastic_ips"] ||= {}
        @output_state["elastic_ips"][name] = {}
        ips = []

        job["instances"].times do
          ips << elastic_ips.shift
        end
        @output_state["elastic_ips"][name]["ips"] = ips

      end
      config["elastic_ips"].each do |name, job|
        if job["dns_record"]
          say "adding A record for #{job["dns_record"]}.#{config["vpc"]["domain"]}"
          route53.add_record(job["dns_record"], config["vpc"]["domain"], @output_state["elastic_ips"][name]["ips"])
          @output_state["elastic_ips"][name]["dns_record"] = job["dns_record"]
        end
      end

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
      route53 = Bosh::Aws::Route53.new(details["aws"])

      err("#{vpc.instances_count} instance(s) running in #{vpc.vpc_id} - delete them first") if vpc.instances_count > 0

      dhcp_options = vpc.dhcp_options

      vpc.delete_security_groups
      vpc.delete_subnets
      vpc.delete_vpc
      dhcp_options.delete

      if details["elastic_ips"]
        details["elastic_ips"].values.each do |job|
          ec2.release_elastic_ips(job["ips"])
          if job["dns_record"]
            route53.delete_record(job["dns_record"], details["vpc"]["domain"])
          end
        end
      end

      say "deleted VPC and all dependencies".green
    end

    usage "aws empty s3"
    desc "empty and delete all s3 buckets"

    def empty_s3(config_file)
      config = load_yaml config_file

      s3 = Bosh::Aws::S3.new(config["aws"])

      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Buckets:\n\t#{s3.bucket_names.join("\n\t")}")

      s3.empty if non_interactive? || agree("Are you sure you want to empty and delete all buckets?")
    end

    usage "aws terminate_all ec2"
    desc "terminates all EC2 instances and attached EBS volumes"

    def terminate_all_ec2(config_file)
      credentials = load_yaml(config_file)["aws"]
      ec2 = Bosh::Aws::EC2.new(credentials)

      formatted_names = ec2.instance_names.map { |id, name| "#{name} (id: #{id})" }
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Instances:\n\t#{formatted_names.join("\n\t")}")

      ec2.terminate_instances if non_interactive? || agree("Are you sure you want to terminate all EC2 instances and their associated EBS volumes?")
    end

    usage "aws delete_all rds databases"
    desc "delete all RDS database instances"

    def delete_all_rds_dbs(config_file)
      credentials = load_yaml(config_file)["aws"]
      rds = Bosh::Aws::RDS.new(credentials)

      formatted_names = rds.database_names.map {|instance, db| "#{instance}\t(database_name: #{db})"}
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Database Instances:\n\t#{formatted_names.join("\n\t")}")

      rds.delete_databases if non_interactive? || agree("Are you sure you want to delete all databases?")
    end

    private

    def flush_output_state(file_path)
      File.open(file_path, 'w') { |f| f.write output_state.to_yaml }
    end

    def load_yaml(file)
      YAML::load(ERB.new(File.read(file)).result)
    rescue
      err "unable to read #{file}".red
    end
  end
end
