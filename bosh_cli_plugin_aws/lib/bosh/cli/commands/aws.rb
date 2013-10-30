require 'aws-sdk'
require 'securerandom'
require_relative '../../../bosh_cli_plugin_aws'
require 'bosh_cli_plugin_aws/destroyer'
require 'bosh_cli_plugin_aws/rds_destroyer'
require 'bosh_cli_plugin_aws/vpc_destroyer'

module Bosh::Cli::Command
  class AWS < Base
    DEFAULT_CIDR = '10.0.0.0/16' # KILL

    attr_reader :output_state, :config_dir, :ec2
    attr_accessor :vpc

    def initialize(runner = [])
      super(runner)
      @output_state = {}
    end

    usage 'aws'
    desc 'show bosh aws sub-commands'
    def help
      say "bosh aws sub-commands:\n"
      commands = Bosh::Cli::Config.commands.values.find_all { |command| command.usage =~ /^aws/ }
      Bosh::Cli::Command::Help.list_commands(commands)
    end

    usage 'aws bootstrap micro'
    desc 'rm deployments dir, creates a deployments/micro/micro_bosh.yml and deploys the microbosh'
    def bootstrap_micro
      options[:hm_director_password] = SecureRandom.base64
      options[:hm_director_user] ||= 'hm'

      bootstrap = Bosh::Aws::MicroBoshBootstrap.new(runner, options)
      bootstrap.start

      bootstrap.create_user(options[:hm_director_user], options[:hm_director_password])

      if interactive?
        username = ask('Enter username: ')
        password = ask('Enter password: ') { |q| q.echo = '*' }

        if username.blank? || password.blank?
          err('Please enter username and password')
        end

        bootstrap.create_user(username, password)
      else
        bootstrap.create_user('admin', SecureRandom.base64)
      end
    end

    usage 'aws bootstrap bosh'
    desc 'bootstrap full bosh deployment'
    def bootstrap_bosh(config_file = nil)
      target_required
      err "To bootstrap BOSH, first log in to `#{config.target}'" unless logged_in?

      options[:hm_director_user] ||= 'hm'
      options[:hm_director_password] = SecureRandom.base64

      bootstrap = Bosh::Aws::BoshBootstrap.new(director, s3(config_file), self.options)
      bootstrap.start

      say 'For security purposes, please provide a username and password for BOSH Director'
      username = ask('Enter username: ')
      password = ask('Enter password: ') { |q| q.echo = '*' }

      bootstrap.create_user(username, password)

      say "BOSH deployed successfully. You are logged in as #{username}."

      bootstrap.create_user(options[:hm_director_user], options[:hm_director_password])
    rescue Bosh::Aws::BootstrapError => e
      err "Unable to bootstrap bosh: #{e.message}"
    end

    usage 'aws generate micro_bosh'
    desc 'generate micro_bosh.yml'
    def create_micro_bosh_manifest(vpc_receipt_file, route53_receipt_file)
      vpc_config = load_yaml_file(vpc_receipt_file)
      route53_config = load_yaml_file(route53_receipt_file)

      options[:hm_director_user] ||= 'hm'
      options[:hm_director_password] = SecureRandom.base64

      manifest = Bosh::Aws::MicroboshManifest.new(vpc_config, route53_config, options)

      write_yaml(manifest, manifest.file_name)
    end

    usage 'aws generate bosh'
    desc 'generate bosh.yml deployment manifest'
    def create_bosh_manifest(vpc_receipt_file, route53_receipt_file, bosh_rds_receipt_file)
      target_required

      options[:hm_director_user] ||= 'hm'
      options[:hm_director_password] = SecureRandom.base64

      vpc_config = load_yaml_file(vpc_receipt_file)
      route53_config = load_yaml_file(route53_receipt_file)
      bosh_rds_config = load_yaml_file(bosh_rds_receipt_file)
      bosh_manifest = Bosh::Aws::BoshManifest.new(vpc_config, route53_config, director.uuid, bosh_rds_config, options)

      write_yaml(bosh_manifest, bosh_manifest.file_name)
    end

    usage 'aws generate bat'
    desc 'generate bat.yml'
    def create_bat_manifest(vpc_receipt_file, route53_receipt_file, stemcell_version, stemcell_name)
      target_required

      vpc_config = load_yaml_file(vpc_receipt_file)
      route53_config = load_yaml_file(route53_receipt_file)
      manifest = Bosh::Aws::BatManifest.new(
        vpc_config, route53_config, stemcell_version, director.uuid, stemcell_name)

      write_yaml(manifest, manifest.file_name)
    end

    usage 'aws create'
    desc 'create everything in migrations'
    option '--trace', 'print all HTTP traffic'
    def create(config_file = nil)
      if !!options[:trace]
         require 'logger'
         ::AWS.config(:logger => Logger.new($stdout), :http_wire_trace => true)
      end

      Bosh::Aws::Migrator.new(load_config(config_file)).migrate
    end

    usage 'aws create s3'
    desc 'create only the s3 buckets'
    def create_s3(config_file = nil)
      Bosh::Aws::Migrator.new(load_config(config_file)).migrate_version('20130412192351')
    end

    usage 'aws create key_pairs'
    desc 'creates only the key pairs'
    def create_key_pairs(config_file = nil)
      Bosh::Aws::Migrator.new(load_config(config_file)).migrate_version('20130412000811')
    end

    usage 'aws create route53 records'
    desc 'creates only the Route 53 records'
    def create_route53_records(config_file = nil)
      Bosh::Aws::Migrator.new(load_config(config_file)).migrate_version('20130412181302')
    end

    usage 'aws create vpc'
    desc 'creates only the VPC'
    def create_vpc(config_file = nil)
      Bosh::Aws::Migrator.new(load_config(config_file)).migrate_version('20130412004642')
    end

    usage 'aws destroy'
    desc 'destroy everything in an AWS account'
    def destroy(config_file = nil)
      config = load_config(config_file)

      rds_destroyer = Bosh::Aws::RdsDestroyer.new(self, config)
      vpc_destroyer = Bosh::Aws::VpcDestroyer.new(self, config)
      destroyer = Bosh::Aws::Destroyer.new(self, config, rds_destroyer, vpc_destroyer)

      destroyer.ensure_not_production!
      destroyer.delete_all_elbs
      destroyer.delete_all_ec2
      destroyer.delete_all_ebs
      destroyer.delete_all_rds
      destroyer.delete_all_s3
      destroyer.delete_all_vpcs
      destroyer.delete_all_key_pairs
      destroyer.delete_all_elastic_ips

      delete_all_security_groups(config_file)
      delete_all_route53_records(config_file)
    end

    private

    def s3(config_file)
      config = load_config(config_file)
      Bosh::Aws::S3.new(config['aws'])
    end

    def delete_vpc(details_file)
      details = load_yaml_file details_file

      ec2 = Bosh::Aws::EC2.new(details['aws'])
      vpc = Bosh::Aws::VPC.find(ec2, details['vpc']['id'])
      route53 = Bosh::Aws::Route53.new(details['aws'])

      err("#{vpc.instances_count} instance(s) running in #{vpc.vpc_id} - delete them first") if vpc.instances_count > 0

      dhcp_options = vpc.dhcp_options

      Bosh::Common.retryable(sleep: aws_retry_wait_time,
                             tries: 120, on: [::AWS::Errors::Base]) do |tries, e|
        say("unable to delete resource: #{e}") if tries > 0
        vpc.delete_security_groups
        vpc.delete_subnets
        ec2.delete_internet_gateways(ec2.internet_gateway_ids)
        vpc.delete_vpc
        dhcp_options.delete

        if details['key_pairs']
          details['key_pairs'].each do |name|
            ec2.remove_key_pair name
          end
        end

        if details['elastic_ips']
          details['elastic_ips'].values.each do |job|
            ec2.release_elastic_ips(job['ips'])
            if job['dns_record']
              route53.delete_record(job['dns_record'], details['vpc']['domain'])
            end
          end
        end
        true # retryable block must yield true if we only want to retry on Exceptions
      end

      say 'deleted VPC and all dependencies'.make_green
    end

    def delete_server_certificates(config_file)
      config = load_config(config_file)
      credentials = config['aws']
      elb = Bosh::Aws::ELB.new(credentials)
      certificates = elb.server_certificate_names

      if certificates.any? && confirmed?("Are you sure you want to delete all server certificates? (#{certificates.join(', ')})")
        elb.delete_server_certificates
        say 'Server certificates deleted.'
      end
    end

    def delete_all_security_groups(config_file)
      config = load_config(config_file)
      ec2 = Bosh::Aws::EC2.new(config['aws'])

      if confirmed?('Are you sure you want to delete all security groups?')
        Bosh::Common.retryable(sleep: aws_retry_wait_time,
                               tries: 120, on: [::AWS::EC2::Errors::InvalidGroup::InUse]) do |tries, e|
          say("unable to delete security groups: #{e}") if tries > 0
          ec2.delete_all_security_groups
          true # retryable block must yield true if we only want to retry on Exceptions
        end
      end
    end

    def delete_all_route53_records(config_file)
      config = load_config(config_file)
      route53 = Bosh::Aws::Route53.new(config['aws'])

      say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)

      omit_types = options[:omit_types] || %w[NS SOA]
      if omit_types.empty?
        msg = 'Are you sure you want to delete all records from Route 53?'
      else
        msg = "Are you sure you want to delete all but #{omit_types.join('/')} records from Route 53?"
      end

      route53.delete_all_records(omit_types: omit_types) if confirmed?(msg)
    end

    def deployment_manifest_state
      @output_state['deployment_manifest'] ||= {}
    end

    def deployment_properties
      deployment_manifest_state['properties'] ||= {}
    end

    def flush_output_state(file_path)
      File.open(file_path, 'w') { |f| f.write output_state.to_yaml }
    end

    def default_config_file
      File.expand_path(File.join(
        File.dirname(__FILE__), '..', '..', '..', '..', 'templates', 'aws_configuration_template.yml.erb'
      ))
    end

    def load_config(config_file=nil)
      config_file ||= default_config_file

      Bosh::Aws::AwsConfig.new(config_file).configuration
    end

    def aws_retry_wait_time; 10; end
  end
end
