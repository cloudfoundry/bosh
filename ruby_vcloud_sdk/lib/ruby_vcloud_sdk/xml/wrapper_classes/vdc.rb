module VCloudSdk
  module Xml

    class Vdc < Wrapper
      def add_disk_link
         get_nodes("Link", {"type"=>MEDIA_TYPE[:DISK_CREATE_PARAMS]}).first
      end

      def disks(name = nil)
        if name.nil?
          get_nodes("ResourceEntity", {"type"=>MEDIA_TYPE[:DISK]})
        else
          get_nodes("ResourceEntity",
            {"type"=>MEDIA_TYPE[:DISK], "name"=>name})
        end
      end

      def instantiate_vapp_template_link
        get_nodes("Link",
          {"type"=>MEDIA_TYPE[:INSTANTIATE_VAPP_TEMPLATE_PARAMS]}).first
      end

      def upload_link
        get_nodes("Link",
          {"type"=>MEDIA_TYPE[:UPLOAD_VAPP_TEMPLATE_PARAMS]}).first
      end

      def upload_media_link
        get_nodes("Link", {"type"=>MEDIA_TYPE[:MEDIA]}).first
      end

      # vApp Template names are not unique so multiple ones can be returned.
      def get_vapp_templates(name)
        get_nodes("ResourceEntity",
          {"type"=>MEDIA_TYPE[:VAPP_TEMPLATE], "name"=>name})
      end

      def available_networks
        get_nodes("Network", {"type"=>MEDIA_TYPE[:NETWORK]})
      end

      def available_network(name)
        get_nodes("Network",
          {"type"=>MEDIA_TYPE[:NETWORK], "name"=>name}).first
      end

      def storage_profiles
        get_nodes("VdcStorageProfile",
          {"type"=>MEDIA_TYPE[:VDC_STORAGE_PROFILE]})
      end
    end

  end
end
