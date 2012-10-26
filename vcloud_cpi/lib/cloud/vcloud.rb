require "common/thread_pool"
require "common/thread_formatter"
require "uuidtools"
require "forwardable"

autoload :VCloudCloud, "cloud/vcloud/cloud"

module Bosh
  module Clouds

    class VCloud
      extend Forwardable

      def_delegators :@delegate,
                     :create_stemcell, :delete_stemcell,
                     :create_vm, :delete_vm, :reboot_vm,
                     :configure_networks,
                     :create_disk, :delete_disk,
                     :attach_disk, :detach_disk,
                     :validate_deployment

      def initialize(options)
        @delegate = VCloudCloud::Cloud.new(options)
      end
    end

    Vcloud = VCloud # alias name for dynamic plugin loading
  end

end
