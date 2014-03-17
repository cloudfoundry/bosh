require 'spec_helper'
require 'open3'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud do
  let(:bin_path) { File.expand_path('../../../bin/vsphere_cpi', __FILE__) }
  let(:config) do
    {
      'cloud' => {
        'properties' => {
          'agent' => {
            'ntp' => ['10.80.0.44'],
          },
          'vcenters' => [{
            'host' => ENV.fetch('BOSH_VSPHERE_CPI_HOST'),
            'user' => ENV.fetch('BOSH_VSPHERE_CPI_USER'),
            'password' => ENV.fetch('BOSH_VSPHERE_CPI_PASSWORD', ''),
            'datacenters' => [{
              'name' => ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER', 'BOSH_DC'),
              'vm_folder' => 'ACCEPTANCE_BOSH_VMs',
              'template_folder' => 'ACCEPTANCE_BOSH_Templates',
              'disk_path' => 'ACCEPTANCE_BOSH_Disks',
              'datastore_pattern' => 'jalapeno',
              'persistent_datastore_pattern' => 'jalapeno',
              'allow_mixed_datastores' => true,
              'clusters' => [{
                'BOSH_CL' => { 'resource_pool' => 'ACCEPTANCE_RP' },
              }],
            }]
          }]
        }
      }
    }
  end

  let(:json) { { 'method' => 'ping', 'arguments' => []} }

  before do
    @config_path = Tempfile.new('vsphere_cpi_config').path
    File.open(@config_path, 'w') { |f| f.write(YAML.dump(config)) }
  end

  after do
    FileUtils.rm_rf(@config_path)
  end

  def run_vsphere_cpi
    Open3.popen3(bin_path, @config_path, JSON.dump(json))
  end

  describe 'running commands' do
    it 'ping-pongs' do
      _, stdout, _, exit_status = run_vsphere_cpi
      expect(exit_status.value).to be_success
      expect(stdout.read).to eq('{"result":"pong","error":null}')
    end
  end
end
