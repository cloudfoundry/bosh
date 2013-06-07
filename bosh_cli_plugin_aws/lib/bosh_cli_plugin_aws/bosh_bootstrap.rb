require_relative "bootstrap"
require 'net/https'

module Bosh
  module Aws
    BootstrapError = Class.new(StandardError)

    class BoshBootstrap < Bootstrap
      attr_accessor :director, :s3

      def initialize(director, s3, options)
        self.options = options
        self.options[:non_interactive] = true
        self.director = director
        self.s3 = s3
      end

      def validate_requirements

        release_exist = director.list_releases.detect { |r| r['name'] == 'bosh' }
        stemcell_exist = director.list_stemcells.detect { |r| r['name'] == 'bosh-stemcell' }

        existing_deployments = director.list_deployments.map { |deployment| deployment["name"] }

        if existing_deployments.include? manifest.bosh_deployment_name
          raise BootstrapError, <<-MSG
Deployment `#{manifest.bosh_deployment_name}' already exists.
This command should be used for bootstrapping bosh from scratch.
          MSG
        end

        return release_exist, stemcell_exist
      end

      def start

        release_exist, stemcell_exist = validate_requirements

        generate_manifest
        fetch_and_upload_release unless release_exist
        fetch_and_upload_stemcell unless stemcell_exist

        deploy

        target_bosh_and_log_in
      end

      private

      def manifest
        unless @manifest
          vpc_receipt_filename = File.expand_path("aws_vpc_receipt.yml")
          route53_receipt_filename = File.expand_path("aws_route53_receipt.yml")
          bosh_rds_receipt_filename = File.expand_path("aws_rds_bosh_receipt.yml")

          vpc_config = load_yaml_file(vpc_receipt_filename)
          route53_config = load_yaml_file(route53_receipt_filename)
          bosh_rds_config = load_yaml_file(bosh_rds_receipt_filename)
          @manifest = Bosh::Aws::BoshManifest.new(vpc_config, route53_config, director.uuid, bosh_rds_config, options)
        end

        @manifest
      end

      def generate_manifest
        deployment_folder = File.join("deployments", manifest.deployment_name)

        FileUtils.mkdir_p deployment_folder
        Dir.chdir(deployment_folder) do
          write_yaml(manifest, manifest.file_name)
        end

        deployment_command = Bosh::Cli::Command::Deployment.new
        deployment_command.options = self.options
        deployment_command.set_current(File.join(deployment_folder, manifest.file_name))
      end

      def fetch_and_upload_release
        release_command = Bosh::Cli::Command::Release.new
        release_command.options = self.options
        release_command.upload(bosh_release)
      end

      def target_bosh_and_log_in
        misc_command = Bosh::Cli::Command::Misc.new
        misc_command.options = self.options
        misc_command.set_target(manifest.vip)
        misc_command.options[:target] = manifest.vip
        misc_command.login("admin", "admin")

        self.options[:target] = misc_command.config.target
      end

      def deploy
        deployment_command = Bosh::Cli::Command::Deployment.new
        deployment_command.options = self.options
        deployment_command.perform

        new_director = Bosh::Cli::Director.new("https://#{manifest.vip}:25555", nil, nil,
                                               num_retries: 12, retry_wait_interval: 5)
        new_director.wait_until_ready
      end

      def fetch_and_upload_stemcell
        stemcell_command = Bosh::Cli::Command::Stemcell.new
        stemcell_command.options = self.options
        stemcell_command.upload(bosh_stemcell)
      end

      def bosh_stemcell
        if bosh_stemcell_override
          say("Using stemcell #{bosh_stemcell_override}")
          return bosh_stemcell_override
        end
        s3.copy_remote_file(AWS_JENKINS_BUCKET, "last_successful_bosh-stemcell-aws_light.tgz", "bosh_stemcell.tgz")
      end

      def bosh_release
        if bosh_release_override
          say("Using release #{bosh_release_override}")
          return bosh_release_override
        end
        s3.copy_remote_file(AWS_JENKINS_BUCKET, "bosh-#{bosh_version}.tgz", "bosh_release.tgz")
      end

      def bosh_stemcell_override
        ENV["BOSH_OVERRIDE_LIGHT_STEMCELL_URL"]
      end

      def bosh_release_override
        ENV["BOSH_OVERRIDE_RELEASE_TGZ"]
      end

      def bosh_version
        ENV["BOSH_VERSION_OVERRIDE"] ||
            Bosh::Aws::VERSION.split('.').last
      end
    end
  end
end
