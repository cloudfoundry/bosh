module Bosh::Stemcell
  module Infrastructure
    def self.for(name)
      case name
        when 'openstack'
          OpenStack.new
        when 'aws'
          Aws.new
        when 'vsphere'
          Vsphere.new
        when 'vcloud'
          Vcloud.new
        else
          raise ArgumentError.new("invalid infrastructure: #{name}")
      end
    end

    class Base
      attr_reader :name, :hypervisor, :default_disk_size

      def initialize(options = {})
        @name = options.fetch(:name)
        @supports_light_stemcell = options.fetch(:supports_light_stemcell, false)
        @hypervisor = options.fetch(:hypervisor)
        @default_disk_size = options.fetch(:default_disk_size)
      end

      def light?
        @supports_light_stemcell
      end

      def ==(other)
        name == other.name &&
          hypervisor == other.hypervisor &&
          default_disk_size == other.default_disk_size &&
          light? == other.light?
      end
    end

    class OpenStack < Base
      def initialize
        super(name: 'openstack', hypervisor: 'kvm', default_disk_size: 10240)
      end
    end

    class Vsphere < Base
      def initialize
        super(name: 'vsphere', hypervisor: 'esxi', default_disk_size: 3072)
      end
    end

    class Vcloud < Base
      def initialize
        super(name: 'vcloud', hypervisor: 'esxi', default_disk_size: 3072)
      end
    end

    class Aws < Base
      def initialize
        super(name: 'aws', hypervisor: 'xen', supports_light_stemcell: true, default_disk_size: 2048)
      end
    end
  end
end
