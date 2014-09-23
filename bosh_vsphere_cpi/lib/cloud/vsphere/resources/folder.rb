module VSphereCloud
  class Resources
    class Folder
      attr_reader :mob, :name

      def initialize(name, config)
        @name = name
        @config = config

        find_folder
      end

      private

      def find_folder
        folder = @config.client.find_by_inventory_path([@config.datacenter_name, 'vm', @name])
        raise "Missing folder: #{@name}" if folder.nil?
        @mob = folder
      end
    end
  end
end
