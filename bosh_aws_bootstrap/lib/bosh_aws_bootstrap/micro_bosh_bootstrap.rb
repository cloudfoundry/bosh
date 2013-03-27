require_relative "bootstrap"

module Bosh
  module Aws
    class MicroBoshBootstrap < Bootstrap
      def start
        vpc_receipt_filename = File.expand_path("aws_vpc_receipt.yml")
        route53_receipt_filename = File.expand_path("aws_route53_receipt.yml")

        vpc_config = load_yaml_file(vpc_receipt_filename)
        route53_config = load_yaml_file(route53_receipt_filename)

        rm_files = %w[bosh-deployments.yml micro bosh_registry.log]
        rm_files.each { |file| FileUtils.rm_rf File.join("deployments", file) }
        FileUtils.mkdir_p "deployments/micro"
        Dir.chdir("deployments/micro") do
          manifest = Bosh::Aws::MicroboshManifest.new(vpc_config, route53_config)
          write_yaml(manifest, "micro_bosh.yml")
        end

        Dir.chdir("deployments") do
          micro = Bosh::Cli::Command::Micro.new(runner)
          micro.options = self.options
          micro.micro_deployment("micro")
          micro.perform(micro_ami)
        end

        misc = Bosh::Cli::Command::Misc.new(runner)
        misc.options = self.options
        misc.login("admin", "admin")
      end

      def micro_ami
        ENV["BOSH_OVERRIDE_MICRO_STEMCELL_AMI"] ||
            Net::HTTP.get("#{AWS_JENKINS_BUCKET}.s3.amazonaws.com", "/last_successful_micro-bosh-stemcell_ami").strip
      end
    end
  end
end