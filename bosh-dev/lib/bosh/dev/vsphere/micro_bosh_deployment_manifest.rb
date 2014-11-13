require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::VSphere
  class MicroBoshDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, net_type)
      @env = env
      @net_type = net_type
      @filename = 'micro_bosh.yml'

      unless net_type == 'manual'
        raise "Specified #{net_type} networking but environment requires manual"
      end
    end

    def to_h
      {
        'name' => 'microbosh-vsphere-jenkins',
        'network' =>
          { 'ip' => env['BOSH_VSPHERE_MICROBOSH_IP'],
            'netmask' => env['BOSH_VSPHERE_NETMASK'],
            'gateway' => env['BOSH_VSPHERE_GATEWAY'],
            'dns' => [env['BOSH_VSPHERE_DNS']],
            'cloud_properties' => { 'name' => env['BOSH_VSPHERE_NET_ID'] } },
        'resources' =>
          { 'persistent_disk' => 4096,
            'cloud_properties' => { 'ram' => 2048, 'disk' => 8192, 'cpu' => 1 } },
        'cloud' =>
          { 'plugin' => 'vsphere',
            'properties' =>
              { 'agent' => { 'ntp' => [env['BOSH_VSPHERE_NTP_SERVER']] },
                'vcenters' =>
                  [{ 'host' => env['BOSH_VSPHERE_VCENTER'],
                     'user' => env['BOSH_VSPHERE_VCENTER_USER'],
                     'password' => env['BOSH_VSPHERE_VCENTER_PASSWORD'],
                     'datacenters' =>
                       [{ 'name' => env['BOSH_VSPHERE_VCENTER_DC'],
                          'vm_folder' => "#{env['BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX']}_VMs",
                          'template_folder' =>
                            "#{env['BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX']}_Templates",
                          'disk_path' => env['BOSH_VSPHERE_VCENTER_DISK_PATH'] || "#{env['BOSH_VSPHERE_VCENTER_UBOSH_FOLDER_PREFIX']}_Disks",
                          'datastore_pattern' =>
                            env['BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN'],
                          'persistent_datastore_pattern' =>
                            env['BOSH_VSPHERE_VCENTER_UBOSH_DATASTORE_PATTERN'],
                          'allow_mixed_datastores' => true,
                          'clusters' =>
                            [{ env['BOSH_VSPHERE_VCENTER_CLUSTER'] =>
                                 { 'resource_pool' =>
                                     env['BOSH_VSPHERE_VCENTER_RESOURCE_POOL'] } }] }] }] } },
        'apply_spec' =>
          { 'properties' =>
              {
                'ntp' => [env['BOSH_VSPHERE_NTP_SERVER']],
                'vcenter' =>
                  { 'host' => env['BOSH_VSPHERE_VCENTER'],
                    'user' => env['BOSH_VSPHERE_VCENTER_USER'],
                    'password' => env['BOSH_VSPHERE_VCENTER_PASSWORD'],
                    'datacenters' =>
                      [{ 'name' => env['BOSH_VSPHERE_VCENTER_DC'],
                         'vm_folder' => "#{env['BOSH_VSPHERE_VCENTER_FOLDER_PREFIX']}_VMs",
                         'template_folder' =>
                           "#{env['BOSH_VSPHERE_VCENTER_FOLDER_PREFIX']}_Templates",
                         'disk_path' => env['BOSH_VSPHERE_VCENTER_DISK_PATH'] || "#{env['BOSH_VSPHERE_VCENTER_FOLDER_PREFIX']}_Disks",
                         'datastore_pattern' => env['BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN'],
                         'persistent_datastore_pattern' =>
                           env['BOSH_VSPHERE_VCENTER_DATASTORE_PATTERN'],
                         'allow_mixed_datastores' => true,
                         'clusters' =>
                           [{ env['BOSH_VSPHERE_VCENTER_CLUSTER'] =>
                                { 'resource_pool' => env['BOSH_VSPHERE_VCENTER_RESOURCE_POOL']}}]}]}}}}
    end

    private

    attr_reader :env
  end
end
