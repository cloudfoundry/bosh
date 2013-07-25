require 'cloud'
require 'bosh_aws_cpi'
require 'ostruct'
require 'yaml'
require 'rake'
require 'bosh/dev/aws_registry'

module Bosh::Dev
  class Ami
    attr_reader :stemcell

    def initialize(stemcell, aws_registry = AwsRegistry.new)
      @stemcell = stemcell
      @aws_registry = aws_registry
    end

    def publish
      access_key_id = ENV['BOSH_AWS_ACCESS_KEY_ID']
      secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']

      aws = {
        'default_key_name' => 'fake',
        'region' => region,
        'access_key_id' => access_key_id,
        'secret_access_key' => secret_access_key
      }

      # just fake the registry struct, as we don't use it
      options = {
        'aws' => aws,
        'registry' => {
          'endpoint' => 'http://fake.registry',
          'user' => 'fake',
          'password' => 'fake'
        }
      }

      cloud_config = OpenStruct.new(logger: Logger.new('ami.log'), task_checkpoint: nil)
      Bosh::Clouds::Config.configure(cloud_config)

      cloud = Bosh::Clouds::Provider.create('aws', options)

      stemcell.extract do |tmp_dir, stemcell_manifest|
        ami_id = cloud.create_stemcell("#{tmp_dir}/image", stemcell_manifest['cloud_properties'])
        cloud.ec2.images[ami_id].public = true

        ami_id
      end
    end

    def region
      aws_registry.region
    end

    private

    attr_reader :aws_registry
  end
end
