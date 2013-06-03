require 'cloud'
require 'bosh_aws_cpi'
require 'ostruct'
require 'net/http'
require 'yaml'

module Bosh
  module Helpers
    class AwsRegistry
      def region
        Net::HTTP.get('169.254.169.254', '/latest/meta-data/placement/availability-zone').chop
      end
    end

    class Ami
      def initialize(stemcell_tgz, aws_registry=AwsRegistry.new)
        @stemcell_tgz = stemcell_tgz
        @aws_registry = aws_registry
      end

      def publish
        region = aws_registry.region

        access_key_id = ENV['BOSH_AWS_ACCESS_KEY_ID']
        secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']

        aws = {
            "default_key_name" => "fake",
            "region" => region,
            "access_key_id" => access_key_id,
            "secret_access_key" => secret_access_key
        }

        # just fake the registry struct, as we don't use it
        options = {
            "aws" => aws,
            "registry" => {
                "endpoint" => "http://fake.registry",
                "user" => "fake",
                "password" => "fake"
            }
        }

        cloud_config = OpenStruct.new(:logger => Logger.new("ami.log"), :task_checkpoint => nil)
        Bosh::Clouds::Config.configure(cloud_config)

        cloud = Bosh::Clouds::Provider.create("aws", options)

        Dir.mktmpdir do |dir|
          Rake::FileUtilsExt.sh('tar', 'xzf', stemcell_tgz, '--directory', dir)
          stemcell_manifest = "#{dir}/stemcell.MF"
          stemcell_properties = Psych.load_file(stemcell_manifest)
          image = "#{dir}/image"

          ami_id = cloud.create_stemcell(image, stemcell_properties['cloud_properties'])
          cloud.ec2.images[ami_id].public = true

          File.open('stemcell-ami.txt', "w") { |f| f << ami_id }

          stemcell_properties["cloud_properties"]["ami"] = { region => ami_id }

          FileUtils.rm_rf(image)
          FileUtils.touch(image)

          File.open(stemcell_manifest, 'w' ) do |out|
            Psych.dump(stemcell_properties, out )
          end

          light_stemcell_name = File.dirname(stemcell_tgz) + "/light-" + File.basename(stemcell_tgz)
          Dir.chdir(dir) do
            Rake::FileUtilsExt.sh("tar cvzf #{light_stemcell_name} *")
          end

          ami_id
        end
      end

      private
      attr_reader :stemcell_tgz, :aws_registry
    end
  end
end
