require 'bosh/stemcell/definition'

module Bosh::Dev
  class BuildTarget
    attr_reader :build_number, :definition

    def self.from_names(build_number, infrastructure_name, operating_system_name)
      definition = Bosh::Stemcell::Definition.for(infrastructure_name, operating_system_name, 'ruby')

      new(build_number, definition)
    end

    def initialize(build_number, definition)
      @build_number = build_number
      @definition = definition
    end

    def infrastructure
      definition.infrastructure
    end

    def infrastructure_light?
      !!definition.infrastructure.light?
    end
  end
end
