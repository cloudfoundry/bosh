# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer
  class InstanceManager
    class Vcloud < InstanceManager

      def remote_tunnel(port)
        # VCloud / vsphere does not use bosh-registry so no remote_tunnel
        # to bosh-registry is required
      end

      def disk_model
        nil
      end

      def update_spec(spec)
        properties = spec.properties

        properties['vcd'] =
          Config.spec_properties['vcd'] ||
          Config.cloud_options['properties']['vcds'].first.dup

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

      def discover_bosh_ip
        bosh_ip
      end

      def service_ip
        bosh_ip
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        cloud.get_disk_size_mb(cid)
      end

      def persistent_disk_changed?
        Config.resources['persistent_disk'] != disk_size(state.disk_cid)
      end

      private

      FakeRegistry = Struct.new(:port)
      def registry
        @registry ||= FakeRegistry.new(nil)
      end
    end
  end
end
