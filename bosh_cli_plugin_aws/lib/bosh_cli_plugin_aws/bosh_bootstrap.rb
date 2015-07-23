require_relative 'bootstrap'
require 'net/https'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/definition'

module Bosh
  module AwsCliPlugin
    BootstrapError = Class.new(StandardError)

    class BoshBootstrap < Bootstrap
      attr_accessor :director, :s3

      def initialize(director, s3, options)
        self.options = options
        self.options[:non_interactive] = true
        self.director = director
        self.s3 = s3
        @env = ENV.to_hash
      end

      def validate_requirements
        release_exist = director.list_releases.detect { |r| r['name'] == 'bosh' }
        first_stemcell = director.list_stemcells.first

        existing_deployments = director.list_deployments.map { |deployment| deployment['name'] }

        if existing_deployments.include? manifest.bosh_deployment_name
          raise BootstrapError, <<-MSG
Deployment `#{manifest.bosh_deployment_name}' already exists.
This command should be used for bootstrapping bosh from scratch.
          MSG
        end

        return release_exist, first_stemcell
      end

      def start
        release_exist, first_stemcell = validate_requirements

        fetch_and_upload_release unless release_exist
        if first_stemcell
          manifest.stemcell_name = first_stemcell['name']
        else
          manifest.stemcell_name = Bosh::Stemcell::Archive.new(fetch_and_upload_stemcell).name
        end
        generate_manifest

        deploy

        target_bosh_and_log_in
      end

      private

      attr_reader :env

      def manifest
        unless @manifest
          vpc_receipt_filename = File.expand_path('aws_vpc_receipt.yml')
          route53_receipt_filename = File.expand_path('aws_route53_receipt.yml')
          bosh_rds_receipt_filename = File.expand_path('aws_rds_bosh_receipt.yml')

          vpc_config = load_yaml_file(vpc_receipt_filename)
          route53_config = load_yaml_file(route53_receipt_filename)
          bosh_rds_config = load_yaml_file(bosh_rds_receipt_filename)
          @manifest = Bosh::AwsCliPlugin::BoshManifest.new(vpc_config, route53_config, director.uuid, bosh_rds_config, options)
        end

        @manifest
      end

      def generate_manifest
        deployment_folder = File.join('deployments', manifest.deployment_name)

        FileUtils.mkdir_p deployment_folder
        Dir.chdir(deployment_folder) do
          write_yaml(manifest, manifest.file_name)
        end

        deployment_command = Bosh::Cli::Command::Deployment.new
        deployment_command.options = self.options
        deployment_command.set_current(File.join(deployment_folder, manifest.file_name))
      end

      def fetch_and_upload_release
        upload_command = Bosh::Cli::Command::Release::UploadRelease.new
        upload_command.options = self.options
        upload_command.upload(bosh_release)
      end

      def target_bosh_and_log_in
        misc_command = Bosh::Cli::Command::Misc.new
        misc_command.options = self.options
        misc_command.set_target(manifest.vip)
        misc_command.options[:target] = manifest.vip

        login_command = Bosh::Cli::Command::Login.new
        login_command.options = misc_command.options
        login_command.login('admin', 'admin')

        self.options[:target] = login_command.config.target
      end

      def deploy
        deployment_command = Bosh::Cli::Command::Deployment.new
        deployment_command.options = self.options
        deployment_command.perform

        new_director = Bosh::Cli::Client::Director.new("https://#{manifest.vip}:25555", nil,
                                               num_retries: 12, retry_wait_interval: 5)
        new_director.wait_until_ready
      end

      def fetch_and_upload_stemcell
        stemcell_command = Bosh::Cli::Command::Stemcell.new
        stemcell_command.options = options
        stemcell_path = bosh_stemcell
        stemcell_command.upload(stemcell_path)
        stemcell_path
      end

      def bosh_stemcell
        if bosh_stemcell_override
          say("Using stemcell #{bosh_stemcell_override}")
          return bosh_stemcell_override
        end

        s3.copy_remote_file(AWS_JENKINS_BUCKET,
                            "bosh-stemcell/aws/#{latest_aws_ubuntu_bosh_stemcell_filename}",
                            'bosh_stemcell.tgz')
      end

      def latest_aws_ubuntu_bosh_stemcell_filename
        definition = Bosh::Stemcell::Definition.for('aws', 'xen', 'ubuntu', 'trusty', 'go', true)
        Bosh::Stemcell::ArchiveFilename.new('latest', definition, 'bosh-stemcell', 'raw')
      end

      def bosh_release
        if bosh_release_override
          say("Using release #{bosh_release_override}")
          return bosh_release_override
        end
        s3.copy_remote_file(AWS_JENKINS_BUCKET, "release/bosh-#{bosh_version}.tgz", 'bosh_release.tgz')
      end

      def bosh_stemcell_override
        env['BOSH_OVERRIDE_LIGHT_STEMCELL_URL']
      end

      def bosh_release_override
        env['BOSH_OVERRIDE_RELEASE_TGZ']
      end

      def bosh_version
        env['BOSH_VERSION_OVERRIDE'] || Bosh::AwsCliPlugin::VERSION.split('.')[1]
      end
    end
  end
end
