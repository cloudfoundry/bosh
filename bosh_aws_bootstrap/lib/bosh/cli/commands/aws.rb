require_relative "../../../bosh_aws_bootstrap"

module Bosh::Cli::Command
  class AWS < Base
    DEFAULT_CIDR = "10.0.0.0/16" # KILL
    OUTPUT_VPC_FILE_BASE = "create-vpc-output-%s.yml"
    OUTPUT_RDS_FILE_BASE = "create-rds-output-%s.yml"

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

    usage "aws generate micro_bosh"
    desc "generate micro_bosh.yml"
    def create_micro_bosh_manifest(config_file, receipt_file)
      File.open("micro_bosh.yml", "w+") do |f|
        f.write(Bosh::Aws::MicroboshManifest.new(load_yaml_file(config_file), load_yaml_file(receipt_file)).to_yaml)
      end
    end

    usage "aws snapshot deployments"
    desc "snapshot all EBS volumes in all deployments"
    def snapshot_deployments(config_file)
      auth_required
      config = load_yaml_file(config_file)

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
      config = load_yaml_file(config_file)

      ec2 = Bosh::Aws::EC2.new(config["aws"])
      @output_state["aws"] = config["aws"]

      vpc = Bosh::Aws::VPC.create(ec2, config["vpc"]["cidr"], config["vpc"]["instance_tenancy"])
      @output_state["vpc"] = {"id" => vpc.vpc_id, "domain" => config["vpc"]["domain"]}

      if was_vpc_eventually_available?(vpc)
        say "creating internet gateway"
        ec2.create_internet_gateway
        vpc.attach_internet_gateway(ec2.internet_gateway_ids.first)

        subnets = config["vpc"]["subnets"]
        say "creating subnets: #{subnets.keys.join(", ")}"
        vpc.create_subnets(subnets)
        @output_state["vpc"]["subnets"] = vpc.subnets

        say "creating route"
        vpc.make_route_for_internet_gateway(vpc.subnets["bosh"], ec2.internet_gateway_ids.first)

        dhcp_options = config["vpc"]["dhcp_options"]
        say "creating DHCP options"
        vpc.create_dhcp_options(dhcp_options)

        security_groups = config["vpc"]["security_groups"]
        say "creating security groups: #{security_groups.map { |group| group["name"] }.join(", ")}"
        vpc.create_security_groups(security_groups)

        @output_state["key_pairs"] = []
        say "allocating #{config["key_pairs"].length} KeyPair(s)"
        config["key_pairs"].each do |name, path|
          ec2.add_key_pair(name, path)
          @output_state["key_pairs"] << name
        end

        count = config["elastic_ips"].values.reduce(0) { |total, job| total += job["instances"] }
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
            route53.add_record(job["dns_record"], config["vpc"]["domain"], @output_state["elastic_ips"][name]["ips"], {ttl: job["ttl"]})
            @output_state["elastic_ips"][name]["dns_record"] = job["dns_record"]
          end
        end
      else
        err "VPC #{vpc.vpc_id} was not available within 60 seconds, giving up"
      end
    ensure
      file_path = File.join(File.dirname(config_file), OUTPUT_VPC_FILE_BASE % Time.now.strftime("%Y%m%d%H%M%S"))
      flush_output_state file_path

      say "details in #{file_path}"
    end

    usage "aws delete vpc"
    desc "delete a vpc"

    def delete_vpc(details_file)
      details = load_yaml_file details_file

      ec2 = Bosh::Aws::EC2.new(details["aws"])
      vpc = Bosh::Aws::VPC.find(ec2, details["vpc"]["id"])
      route53 = Bosh::Aws::Route53.new(details["aws"])

      err("#{vpc.instances_count} instance(s) running in #{vpc.vpc_id} - delete them first") if vpc.instances_count > 0

      dhcp_options = vpc.dhcp_options

      vpc.delete_security_groups
      vpc.delete_subnets
      ec2.delete_internet_gateways(ec2.internet_gateway_ids)
      vpc.delete_vpc
      dhcp_options.delete

      if details["key_pairs"]
        details["key_pairs"].each do |name|
          ec2.remove_key_pair name
        end
      end

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

    usage "aws create s3"
    desc "create s3 buckets"

    def create_s3(config_file)
      config = load_yaml_file(config_file)

      s3 = Bosh::Aws::S3.new(config["aws"])

      config["s3"].each do |e|
        bucket_name = e["bucket_name"]
        say "creating bucket #{bucket_name}"
        s3.create_bucket(bucket_name)
      end
    end

    usage "aws empty s3"
    desc "empty and delete all s3 buckets"

    def empty_s3(config_file)
      config = load_yaml_file config_file

      check_instance_count(config)

      s3 = Bosh::Aws::S3.new(config["aws"])

      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Buckets:\n\t#{s3.bucket_names.join("\n\t")}")

      s3.empty if non_interactive? || agree("Are you sure you want to empty and delete all buckets?")
    end

    usage "aws terminate_all ec2"
    desc "terminates all EC2 instances and attached EBS volumes"

    def terminate_all_ec2(config_file)
      config = load_yaml_file(config_file)
      credentials = config["aws"]
      check_instance_count(config)
      ec2 = Bosh::Aws::EC2.new(credentials)

      formatted_names = ec2.instance_names.map { |id, name| "#{name} (id: #{id})" }
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Instances:\n\t#{formatted_names.join("\n\t")}")

      if non_interactive? || agree("Are you sure you want to terminate all terminatable EC2 instances and their associated non-persistent EBS volumes?")
        say "Terminating instances and waiting for them to die..."
        if !ec2.terminate_instances
          say "Warning: instances did not terminate yet after 100 retries".red
        end
      end
    end

    usage "aws create rds"
    desc "create all RDS database instances"
    def create_rds_dbs(config_file)
      config = load_yaml_file(config_file)
      credentials = config["aws"]
      rds = Bosh::Aws::RDS.new(credentials)

      config["rds"].each do |rds_db_config|
        name = rds_db_config["name"]
        tag = rds_db_config["tag"]

        unless rds.database_exists?(name)
          # This is a bit odd, and the naturual way would be to just pass creation_opts
          # in directly, but it makes this easier to mock.  Once could argue that the
          # params to create_database should change to just a hash instead of a name +
          # a hash.
          creation_opts = [name]
          creation_opts << rds_db_config["aws_creation_options"] if rds_db_config["aws_creation_options"]
          response = rds.create_database(*creation_opts)
          output_rds_properties(name, tag, response)
        end
      end

      if was_rds_eventually_available?(rds)
        config["rds"].each do |rds_db_config|
          name = rds_db_config["name"]

          if deployment_properties[name]
            db_instance = rds.database(name)
            deployment_properties[name].merge!(
              "address" => db_instance.endpoint_address,
              "port" => db_instance.endpoint_port
            )
          end
        end
      else
        err "RDS was not available within 10 minutes, giving up"
      end

    ensure
      file_path = File.join(File.dirname(config_file), OUTPUT_RDS_FILE_BASE % Time.now.strftime("%Y%m%d%H%M%S"))
      flush_output_state file_path

      say "details in #{file_path}"
    end

    usage "aws delete_all rds"
    desc "delete all RDS database instances"

    def delete_all_rds_dbs(config_file)
      config = load_yaml_file(config_file)
      credentials = config["aws"]
      check_instance_count(config)
      rds = Bosh::Aws::RDS.new(credentials)

      formatted_names = rds.database_names.map { |instance, db| "#{instance}\t(database_name: #{db})" }
      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("Database Instances:\n\t#{formatted_names.join("\n\t")}")

      rds.delete_databases if non_interactive? || agree("Are you sure you want to delete all databases?")
    end

    usage "aws delete_all volumes"
    desc "delete all EBS volumes"
    def delete_all_ebs(config_file)
      config = load_yaml_file(config_file)
      credentials = config["aws"]
      ec2 = Bosh::Aws::EC2.new(credentials)
      check_volume_count(config)

      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".red)
      say("It will delete #{ec2.volume_count} EBS volume(s)")

      if non_interactive? || agree("Are you sure you want to delete all unattached EBS volumes?")
        ec2.delete_volumes
      end
    end

    private

    def was_vpc_eventually_available?(vpc)
      (1..60).any? do |attempt|
        begin
          sleep 1 unless attempt == 1
          vpc.state.to_s == "available"
        rescue AWS::EC2::Errors::InvalidVpcID::NotFound
          # try again
        end
      end
    end

    def was_rds_eventually_available?(rds)
      return true if all_rds_instances_available?(rds, :silent => true)
      (1..60).any? do |attempt|
        sleep 10
        all_rds_instances_available?(rds)
      end
    end

    def all_rds_instances_available?(rds, opts = {})
      silent = opts[:silent]
      say("checking rds status...") unless silent
      rds.databases.all? do |db_instance|
        say("  #{db_instance.db_name} #{db_instance.db_instance_status} #{db_instance.endpoint_address}") unless silent
        !db_instance.endpoint_address.nil?
      end
    end

    def output_rds_properties(name, tag, response)
      deployment_properties[name] = {
        "db_scheme" => response[:engine],
        "roles" => [
          {
            "tag" => "admin",
            "name" => response[:master_username],
            "password" => response[:master_user_password]
          }
        ],
          "databases" => [
            {
              "tag" => tag,
              "name" => name
            }
        ]
      }
    end

    def deployment_manifest_state
      @output_state["deployment_manifest"] ||= {}
    end

    def deployment_properties
      deployment_manifest_state["properties"] ||= {}
    end

    def flush_output_state(file_path)
      File.open(file_path, 'w') { |f| f.write output_state.to_yaml }
    end

    def check_instance_count(config)
      ec2 = Bosh::Aws::EC2.new(config["aws"])
      err("#{ec2.instances_count} instance(s) running.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.") if ec2.instances_count > 20
    end

    def check_volume_count(config)
      ec2 = Bosh::Aws::EC2.new(config["aws"])
      err("#{ec2.volume_count} volume(s) present.  This isn't a dev account (more than 20) please make sure you want to do this, aborting.") if ec2.volume_count > 20
    end

  end
end
