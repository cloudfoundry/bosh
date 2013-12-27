require 'bosh/dev/aws'
require 'aws-sdk'
require 'logger'
require 'common/retryable'

module Bosh::Dev::Aws
  class MicroBoshDeploymentCleaner
    def initialize(manifest)
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      ec2 = AWS::EC2.new(
        access_key_id: @manifest.access_key_id,
        secret_access_key: @manifest.secret_access_key,
      )

      matching_instances = lookup_instances(ec2)
      unless matching_instances.empty?
        matching_instance_names = matching_instances.map { |i| i.tags['Name'] || 'unknown' }.join(', ')
        @logger.info("Terminating instances #{matching_instance_names}")
      end
      matching_instances.each(&:terminate)

      Bosh::Retryable.new(tries: 20, sleep: 20).retryer do
        matching_instances.all? { |i| i.status == :terminated }
      end
    end

    private

    def lookup_instances(ec2)
      # Assumption here is that when director deploys instances
      # it properly tags them with director's name.
      ec2.instances.select do |instance|
        tags = instance.tags.values_at('Name', 'director')
        director_related = tags.include?(@manifest.director_name)
        not_terminated = instance.status != :terminated
        director_related && not_terminated
      end
    end
  end
end
