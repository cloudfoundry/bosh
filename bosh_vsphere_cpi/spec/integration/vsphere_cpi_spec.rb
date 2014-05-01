require 'spec_helper'
require 'open3'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud do
  let(:bin_path) { File.expand_path('../../../bin/vsphere_cpi', __FILE__) }
  let(:db_path) { Tempfile.new('vsphere_cpi.db').path }

  let(:host) { ENV.fetch('BOSH_VSPHERE_CPI_HOST') }
  let(:user) { ENV.fetch('BOSH_VSPHERE_CPI_USER') }
  let(:password) { ENV.fetch('BOSH_VSPHERE_CPI_PASSWORD', '') }
  let(:datacenter_name) { ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER', 'BOSH_DC') }
  let(:config) do
    {
      'db' => {
        'database' => db_path
      },
      'cloud' => {
        'properties' => {
          'agent' => {
            'ntp' => ['10.80.0.44'],
          },
          'vcenters' => [{
            'host' => host,
            'user' => user,
            'password' => password,
            'datacenters' => [{
              'name' => datacenter_name,
              'vm_folder' => ENV.fetch('BOSH_VSPHERE_CPI_VM_FOLDER', 'ACCEPTANCE_BOSH_VMs'),
              'template_folder' => ENV.fetch('BOSH_VSPHERE_CPI_TEMPLATE_FOLDER', 'ACCEPTANCE_BOSH_Templates'),
              'disk_path' => ENV.fetch('BOSH_VSPHERE_CPI_DISK_PATH', 'ACCEPTANCE_BOSH_Disks'),
              'datastore_pattern' => ENV.fetch('BOSH_VSPHERE_CPI_DATASTORE_PATTERN', 'jalapeno'),
              'persistent_datastore_pattern' => ENV.fetch('BOSH_VSPHERE_CPI_PERSISTENT_DATASTORE_PATTERN', 'jalapeno'),
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

  before do
    @config_path = Tempfile.new('vsphere_cpi_config').path
    File.open(@config_path, 'w') { |f| f.write(YAML.dump(config)) }
  end

  def run_vsphere_cpi(json)
    stdin, stdout, stderr, exit_status = Open3.popen3(bin_path, @config_path)
    stdin.puts(JSON.dump(json))
    stdin.close

    expect(exit_status.value).to be_success, "Failure running vsphere cpi #{stderr.read}"
    stdout.read
  end

  describe 'running commands' do
    let(:json) { { 'method' => 'ping', 'arguments' => [], 'context' => { 'director_uuid' => 'abc' } } }

    it 'ping-pongs' do
      output = run_vsphere_cpi(json)
      expect(output).to eq('{"result":"pong","error":null}')
    end
  end

  describe 'migrations' do
    it 'runs migrations on database from config' do
      run_vsphere_cpi({})
      db = Sequel.sqlite(database: db_path)
      result = db["SELECT * FROM schema_migrations"]
      expect(result.count).to be > 0
      expect(result.first[:filename]).to match(/initial/)
    end
  end
end
