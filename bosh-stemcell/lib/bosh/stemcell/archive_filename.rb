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
        infrastructure.name,
        infrastructure.hypervisor,
        operating_system.name,
      ]
      stemcell_filename_parts << "#{agent.name}_agent" unless agent.name == 'ruby'
      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      light ? "light-#{base_name}" : base_name
    end

    def_delegators(
      :@definition,
      :infrastructure,
      :operating_system,
      :agent,
    )

    attr_reader(
      :base_name,
      :version,
      :light,
    )
  end
end
