module VSphereCloud

  class Resources

    class Folder
      attr_reader :mob
      attr_reader :name

      def initialize(name, config)
        @name = name
        @config = config

        find_or_create_folder
      end

      private

      def find_or_create_folder
        folder = find_folder

        if @config.datacenter_use_sub_folder
          @name, @mob = find_or_create_sub_folder(folder)
        else
          @mob = folder
        end
      end

      def find_folder
        folder = @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', @name])
        raise "Missing folder: #{@name}" if folder.nil?
        folder
      end

      def find_or_create_sub_folder(folder)
        parent_folder = folder
        uuid = Bosh::Clouds::Config.uuid
        sub_folder_name = [@name, uuid]
        name_join = sub_folder_name.join("/")

        @config.logger.debug("Attempting to create folder #{name_join}")

        begin
          sub_folder = parent_folder.create_folder(uuid)
          @config.logger.debug("Created folder #{name_join}")
        rescue VimSdk::SoapError => e
          raise e unless VimSdk::Vim::Fault::DuplicateName === e.fault
          sub_folder = @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', sub_folder_name])
          @config.logger.debug("Folder #{name_join} already exists")
        end

        [sub_folder_name, sub_folder]
      end
    end
  end
end
