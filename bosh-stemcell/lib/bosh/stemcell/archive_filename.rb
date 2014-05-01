require 'forwardable'

module Bosh::Stemcell
  class ArchiveFilename
    extend Forwardable

    def initialize(version, definition, base_name, light)
      @version = version
      @definition = definition
      @base_name = base_name
      @light = light
    end

    def to_s
      stemcell_filename_parts = [
        name,
        version,
        @definition.stemcell_name
      ]
      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      light ? "light-#{base_name}" : base_name
    end

    attr_reader(
      :base_name,
      :version,
      :light,
    )
  end
end
