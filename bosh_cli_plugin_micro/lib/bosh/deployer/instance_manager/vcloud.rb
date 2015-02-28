require 'forwardable'

module Bosh::Deployer
  class InstanceManager
    class Vcloud
      extend Forwardable

      def initialize(instance_manager, config, logger)
        @instance_manager = instance_manager
        @config = config
        @logger = logger
      end

      def remote_tunnel
        # VCloud / vsphere does not use bosh-registry so no remote_tunnel
        # to bosh-registry is required
      end

      def update_spec(spec)
        properties = spec.properties

        properties['vcd'] =
          config.spec_properties['vcd'] ||
            config.cloud_options['properties']['vcds'].first.dup

        properties['vcd']['address'] ||= properties['vcd']['url']
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
        instance_manager.cloud.get_disk_size_mb(cid)
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
