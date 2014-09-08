require 'bosh/stemcell/definition'

module Bosh::Dev
  class BuildTarget
    attr_reader :build_number, :definition

    # rubocop:disable Style/ParameterLists
    def self.from_names(
      build_number,
      infrastructure_name,
      hypervisor_name,
      operating_system_name,
      operating_system_version,
      agent_name,
      light
    )
      definition = Bosh::Stemcell::Definition.for(
        infrastructure_name,
        hypervisor_name,
        operating_system_name,
        operating_system_version,
        agent_name,
        light,
      )
      new(build_number, definition)
    end
    # rubocop:enable Style/ParameterLists

    def initialize(build_number, definition)
      @build_number = build_number
      @definition = definition
    end

    def infrastructure
      definition.infrastructure
    end

    def infrastructure_name
      definition.infrastructure.name
    end
  end
end
