module Bosh::Stemcell
  class ArchiveFilename
    def initialize(version, infrastructure, operating_system, base_name, light)
      @version = version
      @infrastructure = infrastructure
      @operating_system = operating_system
      @base_name = base_name
      @light = light
    end

    def to_s
      stemcell_filename_parts = [name, version, infrastructure.name, infrastructure.hypervisor, operating_system.name]

      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      light ? "light-#{base_name}" : base_name
    end

    attr_reader :base_name,
                :version,
                :infrastructure,
                :operating_system,
                :light
  end
end
