require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  class BuildTarget
    attr_reader :build_number, :infrastructure, :operating_system

    def self.from_names(build_number, infrastructure_name, operating_system_name)
      infrastructure = Bosh::Stemcell::Infrastructure.for(infrastructure_name)
      new(
        build_number,
        infrastructure,
        Bosh::Stemcell::OperatingSystem.for(operating_system_name),
        infrastructure.light?,
      )
    end

    def initialize(build_number, infrastructure, operating_system, infrastructure_light)
      @build_number = build_number
      @infrastructure = infrastructure
      @operating_system = operating_system
      @infrastructure_light = infrastructure_light
    end

    def infrastructure_light?
      !!@infrastructure_light
    end
  end
end
