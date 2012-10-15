# Copyright (c) 2009-2012 VMware, Inc.

module VSphereCloud
  class Resources

    # Folder resource.
    class Folder

      # @!attribute mob
      #   @return [Vim::Folder] folder vSphere MOB.
      attr_accessor :mob

      # @!attribute name
      #   @return [String] folder name.
      attr_accessor :name

      # Creates a new Folder resource given the parent datacenter and folder
      #   name.
      #
      # @param [Datacenter] datacenter parent datacenter.
      # @param [String] name folder name.
      # @param [true, false] shared flag signaling to use the director guid as
      #   the namespace for multi tenancy.
      def initialize(datacenter, name, shared)
        client = Config.client
        logger = Config.logger

        folder = client.find_by_inventory_path([datacenter.name, "vm", name])
        raise "Missing folder: #{name}" if folder.nil?

        if shared
          shared_folder = folder

          uuid = Bosh::Clouds::Config.uuid
          name = [name, uuid]

          logger.debug("Search for folder #{name.join("/")}")
          folder = client.find_by_inventory_path([datacenter.name, "vm", name])
          if folder.nil?
            logger.debug("Creating folder #{name.join("/")}")
            folder = shared_folder.create_folder(uuid)
          end
          logger.debug("Found folder #{name.join("/")}: #{folder}")

          @mob = folder
          @name = name
        else
          @mob = folder
          @name = name
        end
      end
    end
  end
end
