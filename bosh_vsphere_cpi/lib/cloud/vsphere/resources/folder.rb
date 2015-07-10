module VSphereCloud
  class Resources
    class Folder
      attr_reader :mob, :path, :path_components

      def initialize(path, logger, client, datacenter_name)
        @path = path
        @logger = logger
        @client = client
        @datacenter_name = datacenter_name
        @path_components = path.split('/')

        @mob = find_or_create_folder(@path_components)
      end

      private

      def find_or_create_folder(path_components)
        if path_components.empty?
          folder = root_vm_folder
          raise "Root VM Folder not found: #{@datacenter_name}/vm" if folder.nil?
          return folder
        end

        folder = find_folder(path_components)
        if folder.nil?
          last_component = path_components.last
          parent_folder = find_or_create_folder(path_components[0..-2])

          begin
            @logger.debug("Creating folder #{last_component}")
            folder = parent_folder.create_folder(last_component)
          rescue VimSdk::SoapError => e
            raise e unless VimSdk::Vim::Fault::DuplicateName === e.fault

            @logger.debug("Folder already exists #{last_component}")
            folder = find_folder(path_components)
          end
        end

        folder
      end

      def find_folder(path_components)
        @client.find_by_inventory_path([@datacenter_name, 'vm', path_components].flatten)
      end

      def root_vm_folder
        @client.find_by_inventory_path([@datacenter_name, 'vm'])
      end
    end
  end
end
