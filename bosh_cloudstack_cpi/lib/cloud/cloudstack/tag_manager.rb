# Copyright (c) 2009-2013 VMware, Inc.

module Bosh::CloudStackCloud
  class TagManager
    MAX_TAG_KEY_LENGTH = 255
    MAX_TAG_VALUE_LENGTH = 255

    def self.tag(taggable, key, value)
      resource_types = {
        Fog::Compute::Cloudstack::Server => "userVm",
        Fog::Compute::Cloudstack::Image => "template",
        Fog::Compute::Cloudstack::Volume => "volume",
        Fog::Compute::Cloudstack::Snapshot => "snapshot",
      }

      unless resource_types.include?(taggable.class)
        raise Bosh::Clouds::CloudError, "Resource type `#{taggable.class}' is not supported"
      end

      return if key.nil? || value.nil?
      trimmed_key = key[0..(MAX_TAG_KEY_LENGTH - 1)]
      trimmed_value = value[0..(MAX_TAG_VALUE_LENGTH - 1)]
      # TODO create Tag model
      taggable.service.create_tags({
          "tags[0].key"   => trimmed_key,
          "tags[0].value" => trimmed_value,
          "resourceids"   => taggable.id,
          "resourcetype"  => resource_types[taggable.class]})
    end

  end
end
