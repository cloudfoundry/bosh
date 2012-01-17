autoload :VSphereCloud, "director/cloud/vsphere/cloud"

module Bosh::Director

  module Clouds

    class VSphere
      extend Forwardable

      def_delegators :@delegate, :create_stemcell, :delete_stemcell, :create_vm, :delete_vm, :configure_networks,
                                 :attach_disk, :detach_disk, :create_disk, :delete_disk, :validate_deployment, :reboot_vm

      def initialize(options)
        @delegate = VSphereCloud::Cloud.new(options)
      end

    end

  end

end
