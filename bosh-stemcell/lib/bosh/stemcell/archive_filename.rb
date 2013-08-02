module Bosh::Stemcell
  class ArchiveFilename
    def initialize(version, infrastructure, name, light)
      @version = version
      @infrastructure = infrastructure
      @name = name
      @light = light
    end

    def to_s
      stemcell_filename_parts = []
      stemcell_filename_parts << version if version == 'latest'
      stemcell_filename_parts << 'light' if light
      stemcell_filename_parts << name
      stemcell_filename_parts << infrastructure.name
      stemcell_filename_parts << infrastructure.hypervisor unless version == 'latest'
      stemcell_filename_parts << version unless version == 'latest'

      "#{stemcell_filename_parts.compact.join('-')}.tgz"
    end

    private

    attr_reader :version
    attr_reader :infrastructure
    attr_reader :name
    attr_reader :light
  end
end