require 'logger'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud/openstack'
require 'common/retryable'
require 'bosh/dev/openstack'

module Bosh::Dev::Openstack
  class MicroBoshDeploymentCleaner
    def initialize(manifest)
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      configure_cpi

      cloud = Bosh::OpenStackCloud::Cloud.new(@manifest.cpi_options)

      servers_collection = cloud.openstack.servers

      Bosh::Retryable.new(tries: 20, sleep: 20).retryer do
        # OpenStack does not return deleted servers on subsequent calls
        servers = find_any_matching_servers(servers_collection)

        matching_server_names = servers.map(&:name).join(', ')
        @logger.info("Destroying servers #{matching_server_names}")

        # calling destroy on a server multiple times is ok
        servers.each(&:destroy)

        servers.empty?
      end
    end

    private

    def configure_cpi
      Bosh::Clouds::Config.configure(OpenStruct.new(
        logger: @logger,
        uuid: nil,
        task_checkpoint: nil,
        db: Sequel.sqlite,
      ))
    end

    def find_any_matching_servers(servers_collection)
      # Assumption here is that when director deploys instances
      # it properly tags them with director's name.
      servers_collection.all.select do |server|
        tags = server.metadata.to_hash.values_at('Name', 'director')
        tags.include?(@manifest.director_name)
      end
    end
  end
end
