require "fileutils"
require "securerandom"
require "sys/filesystem"
require "sequel"

require "common/exec"

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require "cloud"
require "cloud/warden/helpers"
require "cloud/warden/model/disk"
require "cloud/warden/db.rb"
require "cloud/warden/device_pool"
require "cloud/warden/disk_manager"
require "cloud/warden/cloud"
require "cloud/warden/version"

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
