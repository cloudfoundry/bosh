# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer
  class InstanceManager
    class Vsphere
      def initialize(instance_manager, logger)
        @instance_manager = instance_manager
        @logger = logger
      end

      def remote_tunnel
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
        instance_manager.bosh_ip
      end

      def service_ip
        instance_manager.bosh_ip
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        disk_model.first(uuid: cid).size
      end

      def persistent_disk_changed?
        Config.resources['persistent_disk'] != disk_size(instance_manager.state.disk_cid)
      end

      private

      attr_reader :instance_manager, :logger

      FakeRegistry = Struct.new(:port)
      def registry
        @registry ||= FakeRegistry.new(nil)
      end
    end
  end
end
