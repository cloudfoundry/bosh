require 'forwardable'
require 'securerandom'
require 'common/thread_pool'
require 'common/thread_formatter'
require 'ruby_vim_sdk'

require 'cloud/vsphere/retry_block'
require 'cloud/vsphere/agent_env'
require 'cloud/vsphere/client'
require 'cloud/vsphere/cloud'
require 'cloud/vsphere/cloud_searcher'
require 'cloud/vsphere/config'
require 'cloud/vsphere/cluster_config'
require 'cloud/vsphere/disk_provider'
require 'cloud/vsphere/file_provider'
require 'cloud/vsphere/fixed_cluster_placer'
require 'cloud/vsphere/lease_obtainer'
require 'cloud/vsphere/lease_updater'
require 'cloud/vsphere/path_finder'
require 'cloud/vsphere/resources/cluster_provider'
require 'cloud/vsphere/resources/cluster'
require 'cloud/vsphere/resources/datacenter'
require 'cloud/vsphere/resources/datastore'
require 'cloud/vsphere/resources/disk/ephemeral_disk'
require 'cloud/vsphere/resources/folder'
require 'cloud/vsphere/resources/vm'
require 'cloud/vsphere/resources/resource_pool'
require 'cloud/vsphere/resources/scorer'
require 'cloud/vsphere/resources/util'
require 'cloud/vsphere/soap_stub'
require 'cloud/vsphere/vm_creator_builder'
require 'cloud/vsphere/vm_provider'

module Bosh
  module Clouds
    class VSphere
      extend Forwardable

      def_delegators :@delegate,
                     :create_stemcell, :delete_stemcell,
                     :create_vm, :delete_vm, :reboot_vm, :has_vm?,
                     :set_vm_metadata,
                     :configure_networks,
                     :create_disk, :has_disk?, :delete_disk,
                     :attach_disk, :detach_disk,
                     :snapshot_disk, :delete_snapshot,
                     :current_vm_id, :get_disks, :ping, :disk_provider

      def initialize(options)
        @delegate = VSphereCloud::Cloud.new(options)
      end
    end

    Vsphere = VSphere # alias name for dynamic plugin loading
  end
end
