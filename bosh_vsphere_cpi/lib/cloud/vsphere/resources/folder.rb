module VSphereCloud
  class Resources
    class Folder
      attr_reader :mob, :path, :name

      # path - an array of names starting from parent down to child folders
      def initialize(path, config)
        @path = path
        @config = config

        @name = path.join('/')

        @mob = find_or_create_folder
      end

      private

      def find_or_create_folder
        folder = find_folder

        if folder.nil?
          begin
            @config.logger.debug("Creating folder #{@name}")
            folder = parent_folder.create_folder(@path.last)
          rescue VimSdk::SoapError => e
            raise e unless VimSdk::Vim::Fault::DuplicateName === e.fault

            @config.logger.debug("Folder already exists #{@name}")
            folder = find_folder
          end
        end

        folder
      end

      def find_folder
        @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', @path].flatten)
      end

      def parent_folder
        if @path.size > 1
          Folder.new(@path[0..-2], @config).mob
        else
          @config.client.find_by_inventory_path([@config.datacenter_name, 'vm'])
        end
      end
    end
  end
end
