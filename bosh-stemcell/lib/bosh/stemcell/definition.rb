require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/stemcell/agent'

module Bosh::Stemcell
  class Definition
    attr_reader :infrastructure, :hypervisor_name, :operating_system, :agent

    def self.for(
      infrastructure_name,
      hypervisor_name,
      operating_system_name,
      operating_system_version,
      agent_name,
      light
    )
      new(
        Bosh::Stemcell::Infrastructure.for(infrastructure_name),
        hypervisor_name,
        Bosh::Stemcell::OperatingSystem.for(operating_system_name, operating_system_version),
        Bosh::Stemcell::Agent.for(agent_name),
        light
      )
    end

    def initialize(infrastructure, hypervisor_name, operating_system, agent, light)
      @infrastructure = infrastructure
      @hypervisor_name = hypervisor_name
      @operating_system = operating_system
      @agent = agent
      @light = light
    end

    def stemcell_name
      stemcell_name_parts = [
        infrastructure.name,
        hypervisor_name,
        operating_system.name,
      ]
      stemcell_name_parts << operating_system.version if operating_system.version
      stemcell_name_parts << "#{agent.name}_agent" unless agent.name == 'ruby'
      stemcell_name_parts.join('-')
    end

    def ==(other)
      infrastructure == other.infrastructure &&
        operating_system == other.operating_system &&
        agent == other.agent &&
        light? == other.light?
    end

    def light?
      @light
    end
  end
end
