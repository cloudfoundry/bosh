require 'cloud'
require 'bosh_aws_cpi'
require 'ostruct'
require 'net/http'
require 'yaml'
require 'rake'

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
        access_key_id = ENV['BOSH_AWS_ACCESS_KEY_ID']
        secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']

        aws = {
            "default_key_name" => "fake",
            "region" => aws_registry.region,
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

        extract_stemcell(stemcell_tgz) do |tmp_dir, stemcell_properties|
          ami_id = cloud.create_stemcell("#{tmp_dir}/image", stemcell_properties['cloud_properties'])
          cloud.ec2.images[ami_id].public = true

          ami_id
        end
      end

      def publish_light_stemcell(ami_id)
        extract_stemcell(stemcell_tgz, exclude: 'image') do |tmp_dir, stemcell_properties|
          File.open('stemcell-ami.txt', "w") { |f| f << ami_id }
          stemcell_properties["cloud_properties"]["ami"] = {aws_registry.region => ami_id}

          FileUtils.touch("#{tmp_dir}/image")

          File.open("#{tmp_dir}/stemcell.MF", 'w') do |out|
            Psych.dump(stemcell_properties, out)
          end

          light_stemcell_name = File.dirname(stemcell_tgz) + "/light-" + File.basename(stemcell_tgz)
          Dir.chdir(tmp_dir) do
            Rake::FileUtilsExt.sh("tar cvzf #{light_stemcell_name} *")
          end
        end
      end

      private
      attr_reader :stemcell_tgz, :aws_registry

      def extract_stemcell(stemcell_tgz, tar_options, &block)
        Dir.mktmpdir do |tmp_dir|
          tar_cmd = "tar xzf #{stemcell_tgz} --directory #{tmp_dir}"
          tar_cmd << " --exclude=#{tar_options[:exclude]}" if tar_options.has_key?(:exclude)

          Rake::FileUtilsExt.sh(tar_cmd)

          stemcell_properties = Psych.load_file("#{tmp_dir}/stemcell.MF")
          block.call(tmp_dir, stemcell_properties)
        end
      end
    end
  end
end
