require 'forwardable'

module Bosh::Stemcell
  class ArchiveFilename
    extend Forwardable

    def initialize(version, definition, base_name, disk_format)
      @version = version
      @definition = definition
      @base_name = base_name
      @disk_format = disk_format
    end

    def to_s
      stemcell_filename_parts = [
        name,
        version,
        definition.stemcell_name(disk_format)
      ]

      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      definition.light? ? "light-#{base_name}" : base_name
    end

    attr_reader(
      :base_name,
      :version,
      :definition,
      :disk_format,
    )
  end
end
