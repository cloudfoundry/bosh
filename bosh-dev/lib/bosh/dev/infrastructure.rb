module Bosh::Dev
  module Infrastructure
    AWS = 'aws'
    ALL = %w[openstack vsphere] << AWS

    def self.for(name)
      case name
        when 'openstack'
          OpenStack.new
        when 'aws'
          Aws.new
        when 'vsphere'
          Vsphere.new
        else
          raise ArgumentError.new("invalid infrastructure: #{name}")
      end
    end

    class Base
      attr_reader :name

      def initialize(name, supports_light_stemcell=false)
        @name = name
        @supports_light_stemcell = supports_light_stemcell
      end

      def run_system_micro_tests
        Rake::Task["spec:system:#{name}:micro"].invoke
      end

      def light?
        @supports_light_stemcell
      end
    end

    class OpenStack < Base
      def initialize
        super('openstack')
      end
    end

    class Vsphere < Base
      def initialize
        super('vsphere')
      end
    end

    class Aws < Base
      def initialize
        super('aws', true)
      end
    end
  end
end
