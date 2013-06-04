require 'cloud'
require 'bosh_aws_cpi'
require 'ostruct'
require 'yaml'
require 'rake'
require_relative('aws_registry')
require_relative('light_stemcell')

module Bosh
  module Helpers
    class Ami
      attr_reader :stemcell_tgz

      def initialize(stemcell_tgz, aws_registry=AwsRegistry.new)
        @stemcell_tgz = stemcell_tgz
        @aws_registry = aws_registry
      end

      def publish
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

        extract_stemcell do |tmp_dir, stemcell_properties|
          ami_id = cloud.create_stemcell("#{tmp_dir}/image", stemcell_properties['cloud_properties'])
          cloud.ec2.images[ami_id].public = true

          ami_id
        end
      end

      def region
        aws_registry.region
      end

      def extract_stemcell(tar_options={}, &block)
        Dir.mktmpdir do |tmp_dir|
          tar_cmd = "tar xzf #{stemcell_tgz} --directory #{tmp_dir}"
          tar_cmd << " --exclude=#{tar_options[:exclude]}" if tar_options.has_key?(:exclude)

          Rake::FileUtilsExt.sh(tar_cmd)

          stemcell_properties = Psych.load_file("#{tmp_dir}/stemcell.MF")
          block.call(tmp_dir, stemcell_properties)
        end
      end

      def publish_light_stemcell(ami_id)
        LightStemcell.new(self).publish(ami_id)
      end

      private
      attr_reader :aws_registry
    end
  end
end
