require_relative "bootstrap"

module Bosh
  module Aws
    BootstrapError = Class.new(StandardError)

    class BoshBootstrap < Bootstrap
      attr_accessor :director

      def initialize(director, options)
        self.options = options
        self.options[:non_interactive] = true
        self.director = director
      end

      def validate_requirements(release_path)
        Dir.chdir(release_path) do
          unless File.directory?("packages") && File.directory?("jobs") && File.directory?("src")
            raise BootstrapError, "Please point to a valid release folder"
          end
        end

        if !director.list_releases.empty?
          raise BootstrapError, "This target already has a release."
        end

        existing_deployments = director.list_deployments.map { |deployment| deployment["name"] }

        if existing_deployments.include? bosh_manifest.bosh_deployment_name
          raise BootstrapError, <<-MSG
Deployment `#{bosh_manifest.bosh_deployment_name}' already exists.
This command should be used for bootstrapping bosh from scratch.
          MSG
        end
      end

      def start(bosh_repository=nil)
        bosh_repository ||= ENV.fetch('BOSH_REPOSITORY') { raise BootstrapError, "A path to a BOSH source repository must be given as an argument or set in the `BOSH_REPOSITORY' environment variable" }
        release_path = File.join(bosh_repository, "release")

        validate_requirements(release_path)

        create_deployment_manifest
        create_and_upload_release(bosh_repository, release_path)
        fetch_and_upload_stemcell

        deploy

        target_bosh_and_log_in
      end

      private

      def bosh_manifest
        unless @bosh_manifest
          vpc_receipt_filename = File.expand_path("aws_vpc_receipt.yml")
          route53_receipt_filename = File.expand_path("aws_route53_receipt.yml")

          vpc_config = load_yaml_file(vpc_receipt_filename)
          route53_config = load_yaml_file(route53_receipt_filename)
          @bosh_manifest = Bosh::Aws::BoshManifest.new(vpc_config, route53_config, director.uuid)
        end

        @bosh_manifest
      end

      def create_deployment_manifest
        deployment_folder = "deployments/#{bosh_manifest.deployment_name}"
        FileUtils.mkdir_p deployment_folder

        Dir.chdir(deployment_folder) do
          write_yaml(bosh_manifest, bosh_manifest.file_name)

          deployment_command = Bosh::Cli::Command::Deployment.new
          deployment_command.options = self.options
          deployment_command.set_current(bosh_manifest.file_name)

          biff_command = Bosh::Cli::Command::Biff.new
          biff_command.options = self.options

          manifest_path = File.join(File.dirname(__FILE__), "..", "..", "templates", "bosh-min-aws-vpc.yml.erb")
          biff_command.biff(File.expand_path(manifest_path))
        end
      end

      def create_and_upload_release(bosh_repository, release_path)
        Dir.chdir(bosh_repository) do
          Bosh::Exec.sh "bundle exec rake release:create_dev_release"
        end

        Dir.chdir(release_path) do
          release_command = Bosh::Cli::Command::Release.new
          release_command.options = self.options
          release_command.upload
        end
      end

      def target_bosh_and_log_in
        misc_command = Bosh::Cli::Command::Misc.new
        misc_command.options = self.options
        misc_command.set_target(bosh_manifest.vip)
        misc_command.options[:target] = bosh_manifest.vip
        misc_command.login("admin", "admin")

        self.options[:target] = misc_command.config.target
      end

      def deploy
        deployment_command = Bosh::Cli::Command::Deployment.new
        deployment_command.options = self.options
        deployment_command.perform
      end

      def fetch_and_upload_stemcell
        stemcell_command = Bosh::Cli::Command::Stemcell.new
        stemcell_command.options = self.options

        stemcell = Tempfile.new "bosh_stemcell"
        stemcell.write bosh_stemcell
        stemcell.close

        stemcell_command.upload(stemcell.path)
      end

      def bosh_stemcell
        ENV["BOSH_OVERRIDE_LIGHT_STEMCELL_URL"] ||
            Net::HTTP.get("#{AWS_JENKINS_BUCKET}.s3.amazonaws.com", "/last_successful_bosh-stemcell_light.tgz")
      end
    end
  end
end