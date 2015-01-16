module VSphereCloud
  class Resources
    class Folder
      attr_reader :mob, :path, :path_components

      def initialize(path, config)
        @path = path
        @config = config

        @path_components = path.split('/')

        @mob = find_or_create_folder(@path_components)
      end

      private

      def find_or_create_folder(path_components)
        return root_vm_folder if path_components.empty?

        folder = find_folder(path_components)
        if folder.nil?
          last_component = path_components.last
          parent_folder = find_or_create_folder(path_components[0..-2])

          begin
            @config.logger.debug("Creating folder #{last_component}")
            folder = parent_folder.create_folder(last_component)
          rescue VimSdk::SoapError => e
            raise e unless VimSdk::Vim::Fault::DuplicateName === e.fault

            @config.logger.debug("Folder already exists #{last_component}")
            folder = find_folder(path_components)
          end
        end

        folder
      end

      def find_folder(path_components)
        @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', path_components].flatten)
      end

      def root_vm_folder
        @config.client.find_by_inventory_path([@config.datacenter_name, 'vm'])
      end
    end
  end
end
