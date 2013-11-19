module Bosh::Stemcell
  class ArchiveFilename
    # rubocop:disable ParameterLists
    def initialize(version, infrastructure, operating_system, base_name, light, agent_name = 'ruby')
      @version = version
      @infrastructure = infrastructure
      @operating_system = operating_system
      @base_name = base_name
      @light = light
      @agent_name = agent_name
    end
    # rubocop:enable ParameterLists

    def to_s
      stemcell_filename_parts = [
        name,
        version,
        infrastructure.name,
        infrastructure.hypervisor,
        operating_system.name,
      ]
      stemcell_filename_parts << "#{agent_name}_agent" unless agent_name == 'ruby'
      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      light ? "light-#{base_name}" : base_name
    end

    attr_reader(
      :base_name,
      :version,
      :infrastructure,
      :operating_system,
      :light,
      :agent_name,
    )
  end
end
