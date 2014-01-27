# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer
  class InstanceManager
    class Vsphere < InstanceManager
      def remote_tunnel(port)
      end

      def disk_model
        if @disk_model.nil?
          require 'cloud/vsphere'
          @disk_model = VSphereCloud::Models::Disk
        end
        @disk_model
      end

      def update_spec(spec)
        properties = spec.properties

        properties['vcenter'] =
          Config.spec_properties['vcenter'] ||
          Config.cloud_options['properties']['vcenters'].first.dup

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

      def discover_bosh_ip
        bosh_ip
      end

      def service_ip
        bosh_ip
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        disk_model.first(uuid: cid).size
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
