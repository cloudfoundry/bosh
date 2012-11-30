# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Deployer
  class InstanceManager

    class Vcloud < InstanceManager

      def update_spec(spec)
        spec = super(spec)
        properties = spec["properties"]

        properties["vcd"] =
          Config.spec_properties["vcd"] ||
          Config.cloud_options["properties"]["vcds"].first.dup

        properties["vcd"]["address"] ||= properties["vcd"]["url"]

        spec
      end

      # @return [Integer] size in MiB
      def disk_size(cid)
        cloud.get_disk_size_mb(cid)
      end

      def persistent_disk_changed?
        Config.resources['persistent_disk'] != disk_size(state.disk_cid)
      end

      def check_dependencies
        if Bosh::Common.which(%w[genisoimage mkisofs]).nil?
          err("either of 'genisoimage' or 'mkisofs' commands must be present")
        end
      end
    end

  end
end
