require "common/thread_pool"
require "common/thread_formatter"
require "uuidtools"

autoload :VSphereCloud, "cloud/vsphere/cloud"

module Bosh
  module Clouds

    class VSphere
      extend Forwardable

      def_delegators :@delegate,
                     :create_stemcell, :delete_stemcell,
                     :create_vm, :delete_vm, :reboot_vm,
                     :configure_networks,
                     :create_disk, :delete_disk,
                     :attach_disk, :detach_disk,
                     :validate_deployment

      def initialize(options)
        @delegate = VSphereCloud::Cloud.new(options)
      end
    end

    Vsphere = VSphere # alias name for dynamic plugin loading
  end

end
