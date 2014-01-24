require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/stemcell/agent'

module Bosh::Stemcell
  class Definition
    attr_reader :infrastructure, :operating_system, :agent

    def self.for(infrastructure_name, operating_system_name, agent_name)
      new(
        Bosh::Stemcell::Infrastructure.for(infrastructure_name),
        Bosh::Stemcell::OperatingSystem.for(operating_system_name),
        Bosh::Stemcell::Agent.for(agent_name)
      )
    end

    def initialize(infrastructure, operating_system, agent)
      @infrastructure = infrastructure
      @operating_system = operating_system
      @agent = agent
    end

    def ==(other)
      infrastructure == other.infrastructure &&
        operating_system == other.operating_system &&
        agent == other.agent
    end
  end
end
