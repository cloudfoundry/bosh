module VSphereCloud
  class Resources
    class MultiTenantFolder
      attr_reader :mob, :name

      def initialize(parent_folder_name, sub_folder_name, config)
        @parent_folder_name = parent_folder_name
        @sub_folder_name = sub_folder_name
        @name = [parent_folder_name, sub_folder_name]
        @config = config

        find_or_create_sub_folder
      end

      private

      def find_or_create_sub_folder
        parent_folder = find_parent_folder
        name_join = @name.join("/")

        @config.logger.debug("Attempting to create folder #{name_join}")

        begin
          sub_folder = parent_folder.create_folder(@sub_folder_name)
          @config.logger.debug("Created folder #{name_join}")
        rescue VimSdk::SoapError => e
          raise e unless VimSdk::Vim::Fault::DuplicateName === e.fault
          sub_folder = @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', @name])
          @config.logger.debug("Folder #{name_join} already exists")
        end

        @mob = sub_folder
      end

      def find_parent_folder
        folder = @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', @parent_folder_name])
        raise "Missing folder: #{@parent_folder_name}" if folder.nil?
        folder
      end
    end
  end
end
