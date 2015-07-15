require_relative "bootstrap"

module Bosh
  module AwsCliPlugin
    class MicroBoshBootstrap < Bootstrap
      def start
        cleanup_previous_deployments
        generate_deployment_manifest
        deploy

        login("admin", "admin")
      end

      def deploy
        Dir.chdir("deployments") do
          micro = Bosh::Cli::Command::Micro.new(runner)
          micro.options = self.options
          micro.micro_deployment("micro")
          micro.perform(micro_ami)
        end
      end

      def manifest
        unless @manifest
          vpc_receipt_filename = File.expand_path("aws_vpc_receipt.yml")
          route53_receipt_filename = File.expand_path("aws_route53_receipt.yml")

          vpc_config = load_yaml_file(vpc_receipt_filename)
          route53_config = load_yaml_file(route53_receipt_filename)

          @manifest = Bosh::AwsCliPlugin::MicroboshManifest.new(vpc_config, route53_config, options)
        end

        @manifest
      end

      def generate_deployment_manifest
        deployment_folder = File.join("deployments", manifest.deployment_name)

        FileUtils.mkdir_p deployment_folder
        if File.exists?(manifest.certificate.certificate_path)
          FileUtils.cp manifest.certificate.certificate_path, File.join(deployment_folder, manifest.certificate.certificate_path)
        end
        if File.exists?(manifest.certificate.key_path)
          FileUtils.cp manifest.certificate.key_path, File.join(deployment_folder, manifest.certificate.key_path)
        end

        Dir.chdir(deployment_folder) do
          write_yaml(manifest, manifest.file_name)
        end
      end

      def cleanup_previous_deployments
        rm_files = %w[bosh-deployments.yml micro bosh-registry.log]
        rm_files.each { |file| FileUtils.rm_rf File.join("deployments", file) }
      end

      def micro_ami
        ENV["BOSH_OVERRIDE_MICRO_STEMCELL_AMI"] ||
            Net::HTTP.get("#{AWS_JENKINS_BUCKET}.s3.amazonaws.com", "/last_successful-bosh-stemcell-aws_ami_us-east-1").strip
      end
    end
  end
end
