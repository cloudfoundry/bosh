module Bosh::Dev
  module Infrastructure
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
      attr_reader :name, :hypervisor

      def initialize(options = {})
        @name = options.fetch(:name)
        @supports_light_stemcell = options.fetch(:supports_light_stemcell, false)
        @hypervisor = options.fetch(:hypervisor, nil)
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
        super(name: 'openstack', hypervisor: 'kvm')
      end
    end

    class Vsphere < Base
      def initialize
        super(name: 'vsphere')
      end
    end

    class Aws < Base
      def initialize
        super(name: 'aws', supports_light_stemcell: true)
      end
    end
  end
end
