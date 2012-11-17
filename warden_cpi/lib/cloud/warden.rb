require "sequel"
require "fileutils"
require "securerandom"

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "cloud"
require "cloud/warden/helpers"
require "cloud/warden/cloud"
require "cloud/warden/version"
require "cloud/warden/models/vm"

require "warden/client"

module Bosh
  module Clouds
    class Warden
      extend Forwardable

      def_delegators :@delegate,
                     :create_stemcell, :delete_stemcell,
                     :create_vm, :delete_vm, :reboot_vm,
                     :configure_networks,
                     :create_disk, :delete_disk,
                     :attach_disk, :detach_disk,
                     :validate_deployment

      def initialize(options)
        @delegate = WardenCloud::Cloud.new(options)
      end
    end
  end
end
