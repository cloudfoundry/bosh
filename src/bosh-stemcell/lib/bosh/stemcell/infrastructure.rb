module Bosh::Stemcell
  module Infrastructure
    def self.for(name)
      case name
        when 'openstack'
          OpenStack.new
        when 'aws'
          Aws.new
        when 'google'
          Google.new
        when 'vsphere'
          Vsphere.new
        when 'warden'
          Warden.new
        when 'vcloud'
          Vcloud.new
        when 'azure'
          Azure.new
        when 'softlayer'
          Softlayer.new
        when 'null'
          NullInfrastructure.new
        else
          raise ArgumentError.new("invalid infrastructure: #{name}")
      end
    end

    class Base
      attr_reader :name, :hypervisor, :default_disk_size, :disk_formats

      def initialize(options = {})
        @name = options.fetch(:name)
        @supports_light_stemcell = options.fetch(:supports_light_stemcell, false)
        @hypervisor = options.fetch(:hypervisor)
        @default_disk_size = options.fetch(:default_disk_size)
        @disk_formats = options.fetch(:disk_formats)
      end

      def default_disk_format
        disk_formats.first
      end

      def additional_cloud_properties
        {}
      end

      def ==(other)
        name == other.name &&
          hypervisor == other.hypervisor &&
          default_disk_size == other.default_disk_size
      end
    end

    class NullInfrastructure < Base
      def initialize
        super(name: 'null', hypervisor: 'null', default_disk_size: -1, disk_formats: [])
      end
    end

    class OpenStack < Base
      def initialize
        super(name: 'openstack', hypervisor: 'kvm', default_disk_size: 3072, disk_formats: ['qcow2', 'raw'])
      end

      def additional_cloud_properties
        {'auto_disk_config' => true}
      end
    end

    class Vsphere < Base
      def initialize
        super(name: 'vsphere', hypervisor: 'esxi', default_disk_size: 3072, disk_formats: ['ovf'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Vcloud < Base
      def initialize
        super(name: 'vcloud', hypervisor: 'esxi', default_disk_size: 3072, disk_formats: ['ovf'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Aws < Base
      def initialize
        super(
          name: 'aws',
          hypervisor: 'xen',
          supports_light_stemcell: true,
          default_disk_size: 3072,
          disk_formats: ['raw']
        )
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Google < Base
      def initialize
        super(name: 'google', hypervisor: 'kvm', default_disk_size: 3072, disk_formats: ['rawdisk'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Warden < Base
      def initialize
        super(name: 'warden', hypervisor: 'boshlite', default_disk_size: 2048, disk_formats: ['files'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Azure < Base
      def initialize
        super(name: 'azure', hypervisor: 'hyperv', default_disk_size: 3072, disk_formats: ['vhd'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end

    class Softlayer < Base
      def initialize
        super(name: 'softlayer', hypervisor: 'esxi', default_disk_size: 3072, disk_formats: ['ovf'])
      end

      def additional_cloud_properties
        {'root_device_name' => '/dev/sda1'}
      end
    end
  end
end
