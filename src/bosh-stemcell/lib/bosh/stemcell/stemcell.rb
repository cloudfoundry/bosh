module Bosh
  module Stemcell
    class Stemcell
      attr_reader :version, :definition, :disk_format, :base_name

      def initialize(definition, base_name, version, disk_format)
        @definition = definition
        @base_name = base_name
        @version = version
        @disk_format = disk_format
      end

      def infrastructure
        @definition.infrastructure
      end

      def name
        ArchiveFilename.new(version, definition, base_name, disk_format).to_s
      end
    end
  end
end
