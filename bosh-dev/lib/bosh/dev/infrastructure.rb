module Bosh::Dev
  class Infrastructure
    AWS = 'aws'
    ALL = %w[openstack vsphere] << AWS

    attr_reader :name

    def initialize(name)
      raise ArgumentError.new("invalid infrastructure: #{name}") unless ALL.include?(name)

      @name = name
    end

    def run_system_micro_tests
      Rake::Task["spec:system:#{name}:micro"].invoke
    end

    def light?
      name == AWS
    end
  end
end
