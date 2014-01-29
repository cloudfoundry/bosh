require 'bosh/deployer/registry'
require 'bosh/deployer/remote_tunnel'
require 'bosh/deployer/ssh_server'

module Bosh::Deployer
  class InstanceManager
    class Openstack < InstanceManager
      def initialize(config, config_sha1, ui_messager)
        super

        @registry = Registry.new(
          Config.cloud_options['properties']['registry']['endpoint'],
          'openstack',
          Config.cloud_options['properties']['openstack'],
          @deployments,
          logger,
        )

        properties = Config.cloud_options['properties']
        ssh_user = properties['openstack']['ssh_user']
        ssh_port = properties['openstack']['ssh_port'] || 22
        ssh_wait = properties['openstack']['ssh_wait'] || 60

        key = properties['openstack']['private_key']
        err 'Missing properties.openstack.private_key' unless key
        ssh_key = File.expand_path(key)
        unless File.exists?(ssh_key)
          err "properties.openstack.private_key '#{key}' does not exist"
        end
        ssh_server = SshServer.new(ssh_user, ssh_key, ssh_port, logger)
        @remote_tunnel = RemoteTunnel.new(ssh_server, ssh_wait, logger)
      end

      def remote_tunnel(port)
        @remote_tunnel.create(Config.bosh_ip, port)
      end

      def disk_model
        nil
      end

      def update_spec(spec)
        properties = spec.properties

        properties['openstack'] =
          Config.spec_properties['openstack'] ||
          Config.cloud_options['properties']['openstack'].dup

        properties['openstack']['registry'] = Config.cloud_options['properties']['registry']
        properties['openstack']['stemcell'] = Config.cloud_options['properties']['stemcell']

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
        save_state
      end

      def discover_bosh_ip
        if state.vm_cid
          floating_ip = cloud.openstack.servers.get(state.vm_cid).floating_ip_address
          ip = floating_ip || service_ip

          if ip != Config.bosh_ip
            Config.bosh_ip = ip
            logger.info("discovered bosh ip=#{Config.bosh_ip}")
          end
        end

        Config.bosh_ip
      end

      def service_ip
        cloud.openstack.servers.get(state.vm_cid).private_ip_address
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        # OpenStack stores disk size in GiB but we work with MiB
        cloud.openstack.volumes.get(cid).size * 1024
      end

      def persistent_disk_changed?
        # since OpenStack stores disk size in GiB and we use MiB there
        # is a risk of conversion errors which lead to an unnecessary
        # disk migration, so we need to do a double conversion
        # here to avoid that
        requested = (Config.resources['persistent_disk'] / 1024.0).ceil * 1024
        requested != disk_size(state.disk_cid)
      end

      private

      attr_reader :registry
    end
  end
end
