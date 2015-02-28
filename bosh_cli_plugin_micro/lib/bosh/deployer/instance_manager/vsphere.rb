require 'forwardable'

module Bosh::Deployer
  class InstanceManager
    class Vsphere
      extend Forwardable

      def initialize(instance_manager, config, logger)
        @instance_manager = instance_manager
        @config = config
        @logger = logger
      end

      def remote_tunnel
      end

      def update_spec(spec)
        properties = spec.properties

        properties['vcenter'] =
          config.spec_properties['vcenter'] ||
            config.cloud_options['properties']['vcenters'].first.dup

        properties['vcenter']['address'] ||= properties['vcenter']['host']
      end

      def check_dependencies
        if Bosh::Common.which(%w[genisoimage mkisofs]).nil?
          err("either of 'genisoimage' or 'mkisofs' commands must be present")
        end
      end

      def start
      end

      def stop
      end

      def_delegators(
        :config,
        :internal_services_ip,
        :agent_services_ip,
        :client_services_ip,
      )

      # @return [Integer] size in MiB
      def disk_size(cid)
        instance_manager.cloud.disk_provider.find(cid).size_in_mb
      end

      def persistent_disk_changed?
        config.resources['persistent_disk'] != disk_size(instance_manager.state.disk_cid)
      end

      private

      attr_reader :instance_manager, :logger, :config

      FakeRegistry = Struct.new(:port)
      def registry
        @registry ||= FakeRegistry.new(nil)
      end
    end
  end
end
