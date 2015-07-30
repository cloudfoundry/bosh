# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::AwsCloud

  module Helpers
    def default_ephemeral_disk_mapping
       { '/dev/sdb' => 'ephemeral0' }
    end

    def ebs_ephemeral_disk_mapping(volume_size_in_gb, volume_type)
      [
        {
          device_name: '/dev/sdb',
          ebs: {
            volume_size: volume_size_in_gb,
            volume_type: volume_type,
            delete_on_termination: true,
          },
        },
      ]
    end

    ##
    # Raises CloudError exception
    #
    def cloud_error(message)
      if @logger
        @logger.error(message)
      end
      raise Bosh::Clouds::CloudError, message
    end

    def extract_security_groups(networks_spec)
      networks_spec.
          values.
          select { |network_spec| network_spec.has_key? "cloud_properties" }.
          map { |network_spec| network_spec["cloud_properties"] }.
          select { |cloud_properties| cloud_properties.has_key? "security_groups" }.
          map { |cloud_properties| Array(cloud_properties["security_groups"]) }.
          flatten.
          sort.
          uniq
    end
  end
end

