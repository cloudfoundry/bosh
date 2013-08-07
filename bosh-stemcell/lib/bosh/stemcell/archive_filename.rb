module Bosh::Stemcell
  class ArchiveFilename
    def initialize(version, infrastructure, name, light)
      @name = light ? "light-#{name}" : name
      @version = version
      @infrastructure = infrastructure
    end

    def to_s
      stemcell_filename_parts = [name, version, infrastructure.name, infrastructure.hypervisor]

      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    attr_reader :name
    attr_reader :version
    attr_reader :infrastructure
  end
end
