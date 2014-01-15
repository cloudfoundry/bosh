require 'bosh/stemcell/definition'

require 'forwardable'

module Bosh::Dev
  class BuildTarget
    extend Forwardable
    def_delegators :@definition, :infrastructure, :operating_system
    attr_reader :build_number

    def self.from_names(build_number, infrastructure_name, operating_system_name)
      definition = Bosh::Stemcell::Definition.for(infrastructure_name, operating_system_name, 'ruby')

      new(build_number, definition)
    end

    def initialize(build_number, definition)
      @build_number = build_number
      @definition = definition
    end

    def infrastructure_light?
      !!infrastructure.light?
    end
  end
end
