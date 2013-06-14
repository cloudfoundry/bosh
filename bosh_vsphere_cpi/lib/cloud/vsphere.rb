require "common/thread_pool"
require "common/thread_formatter"
require "securerandom"

autoload :VSphereCloud, "cloud/vsphere/cloud"

module Bosh
  module Clouds

    # TODO: figure out why this metaprogramming exists and if possible, get rid of it.
    # Ripping it out currently makes a test fail in mysterious ways.
    class VSphere
      extend Forwardable

      def_delegators :@delegate,
                     :create_stemcell, :delete_stemcell,
                     :create_vm, :delete_vm, :reboot_vm, :has_vm?,
                     :set_vm_metadata,
                     :configure_networks,
                     :create_disk, :delete_disk,
                     :attach_disk, :detach_disk,
                     :validate_deployment,
                     :snapshot_disk, :delete_snapshot,
                     :current_vm_id, :get_disks

      def initialize(options)
        @delegate = VSphereCloud::Cloud.new(options)
      end
    end

    Vsphere = VSphere # alias name for dynamic plugin loading
  end

end
