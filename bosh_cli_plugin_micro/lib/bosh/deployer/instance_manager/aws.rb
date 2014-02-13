require 'bosh/deployer/registry'
require 'bosh/deployer/remote_tunnel'
require 'bosh/deployer/ssh_server'

module Bosh::Deployer
  class InstanceManager
    class Aws
      def initialize(instance_manager, logger)
        @instance_manager = instance_manager
        @logger = logger
        properties = Config.cloud_options['properties']

        @registry = Registry.new(
          properties['registry']['endpoint'],
          'aws',
          properties['aws'],
          instance_manager,
          logger,
        )

        ssh_key, ssh_port, ssh_user, ssh_wait = ssh_properties(properties)

        ssh_server = SshServer.new(ssh_user, ssh_key, ssh_port, logger)
        @remote_tunnel = RemoteTunnel.new(ssh_server, ssh_wait, logger)
      end

      def remote_tunnel
        @remote_tunnel.create(instance_manager.bosh_ip, registry.port)
      end

      def disk_model
        nil
      end

      def update_spec(spec)
        properties = spec.properties

        # pick from micro_bosh.yml the aws settings in
        # `apply_spec` section (apply_spec.properties.aws),
        # and if it doesn't exist, use the bosh deployer
        # aws properties (cloud.properties.aws)
        properties['aws'] =
          Config.spec_properties['aws'] ||
          Config.cloud_options['properties']['aws'].dup

        properties['aws']['registry'] = Config.cloud_options['properties']['registry']
        properties['aws']['stemcell'] = Config.cloud_options['properties']['stemcell']

        spec.delete('networks')
      end

      def check_dependencies
        # nothing to check, move on...
      end

      def start
        registry.start
      end

      def stop
        registry.stop
        instance_manager.save_state
      end

      def discover_bosh_ip
        if instance_manager.state.vm_cid
          # choose elastic IP over public, as any agent connecting to the
          # deployed micro bosh will be cut off from the public IP when
          # we re-deploy micro bosh
          instance = instance_manager.cloud.ec2.instances[instance_manager.state.vm_cid]
          if instance.has_elastic_ip?
            ip = instance.elastic_ip.public_ip
          else
            ip = instance.public_ip_address
          end

          if ip && ip != instance_manager.bosh_ip
            instance_manager.bosh_ip = ip
            logger.info("discovered bosh ip=#{instance_manager.bosh_ip}")
          end
        end

        instance_manager.bosh_ip
      end

      def service_ip
        instance_manager.cloud.ec2.instances[instance_manager.state.vm_cid].private_ip_address
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        # AWS stores disk size in GiB but the CPI uses MiB
        instance_manager.cloud.ec2.volumes[cid].size * 1024
      end

      def persistent_disk_changed?
        # since AWS stores disk size in GiB and the CPI uses MiB there
        # is a risk of conversion errors which lead to an unnecessary
        # disk migration, so we need to do a double conversion
        # here to avoid that
        requested = (Config.resources['persistent_disk'] / 1024.0).ceil * 1024
        requested != disk_size(instance_manager.state.disk_cid)
      end

      private

      attr_reader :registry, :instance_manager, :logger

      def ssh_properties(properties)
        ssh_user = properties['aws']['ssh_user']
        ssh_port = properties['aws']['ssh_port'] || 22
        ssh_wait = properties['aws']['ssh_wait'] || 60

        key = properties['aws']['ec2_private_key']
        err 'Missing properties.aws.ec2_private_key' unless key
        ssh_key = File.expand_path(key)
        unless File.exists?(ssh_key)
          err "properties.aws.ec2_private_key '#{key}' does not exist"
        end

        [ssh_key, ssh_port, ssh_user, ssh_wait]
      end
    end
  end
end
