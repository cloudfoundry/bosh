# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class UnknownInfrastructure < StandardError; end

  class Infrastructure

    def initialize(infrastructure_name)
      @name = infrastructure_name
      # TODO: add to loadpath?
      infrastructure = File.join(File.dirname(__FILE__), 'infrastructure', "#{infrastructure_name}.rb")

      if File.exist?(infrastructure)
        load infrastructure
      else
        raise UnknownInfrastructure, "infrastructure '#{infrastructure_name}' not found"
      end
    end

    def infrastructure
      Infrastructure.const_get(@name.capitalize).new
    end

  end
end
