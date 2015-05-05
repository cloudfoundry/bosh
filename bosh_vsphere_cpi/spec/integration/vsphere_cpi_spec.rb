require 'spec_helper'
require 'open3'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud, external_cpi: true do
  before(:all) do
    @workspace_dir = Dir.mktmpdir('vsphere-cloud-spec')
    @config_path = File.join(@workspace_dir, 'vsphere_cpi_config')
    File.open(@config_path, 'w') { |f| f.write(YAML.dump(config)) }

    stemcell_path = ENV['BOSH_VSPHERE_STEMCELL'] || raise('Missing BOSH_VSPHERE_STEMCELL')

    Dir.mktmpdir do |temp_dir|
      output = `tar -C #{temp_dir} -xzf #{stemcell_path} 2>&1`
      raise "Corrupt image, tar exit status: #{$?.exitstatus} output: #{output}" if $?.exitstatus != 0
      @stemcell_id = external_cpi_result(:create_stemcell,
        "#{temp_dir}/image",
        nil
      )
    end
  end

  after(:all) do
    external_cpi_result(:delete_stemcell, @stemcell_id) if @stemcell_id

    FileUtils.rm_rf(@workspace_dir)
  end

  def config
    return @config if @config
    datacenter_name          = ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER', 'BOSH_DC')
    cluster                  = ENV.fetch('BOSH_VSPHERE_CPI_CLUSTER', 'BOSH_CL')
    second_cluster           = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_CLUSTER', 'BOSH_CL2')

    host                      = ENV.fetch('BOSH_VSPHERE_CPI_HOST')
    user                      = ENV.fetch('BOSH_VSPHERE_CPI_USER')
    password                  = ENV.fetch('BOSH_VSPHERE_CPI_PASSWORD', '')
    resource_pool_name        = ENV.fetch('BOSH_VSPHERE_CPI_RESOURCE_POOL', 'ACCEPTANCE_RP')
    second_resource_pool_name = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_CLUSTER_RESOURCE_POOL', 'ACCEPTANCE_RP')

    client = VSphereCloud::Client.new("https://#{host}/sdk/vimService").tap do |client|
      client.login(user, password, 'en')
    end

    vm_folder_name = ENV.fetch('BOSH_VSPHERE_CPI_VM_FOLDER', 'ACCEPTANCE_BOSH_VMs')
    template_folder_name = ENV.fetch('BOSH_VSPHERE_CPI_TEMPLATE_FOLDER', 'ACCEPTANCE_BOSH_Templates')
    disk_folder_name = ENV.fetch('BOSH_VSPHERE_CPI_DISK_PATH', 'ACCEPTANCE_BOSH_Disks')

    prepare_tests_folder(client, datacenter_name, vm_folder_name)
    prepare_tests_folder(client, datacenter_name, template_folder_name)
    prepare_tests_folder(client, datacenter_name, disk_folder_name)

    @config = {
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
              'vm_folder' => "#{vm_folder_name}/lifecycle_tests",
              'template_folder' => "#{template_folder_name}/lifecycle_tests",
              'disk_path' => "#{disk_folder_name}/lifecycle_tests",
              'datastore_pattern' => ENV.fetch('BOSH_VSPHERE_CPI_DATASTORE_PATTERN', 'jalapeno'),
              'persistent_datastore_pattern' => ENV.fetch('BOSH_VSPHERE_CPI_PERSISTENT_DATASTORE_PATTERN', 'jalapeno'),
              'allow_mixed_datastores' => true,
              'clusters' => [
                {
                  cluster => { 'resource_pool' => resource_pool_name },
                },
                {
                  second_cluster  => { 'resource_pool' => second_resource_pool_name }
                }
              ],
            }]
          }]
        }
      }
    }
  end

  def prepare_tests_folder(client, datacenter_name, parent_folder_name)
    tests_vm_folder = client.find_by_inventory_path([datacenter_name, 'vm', parent_folder_name, 'lifecycle_tests'])
    client.delete_folder(tests_vm_folder) if tests_vm_folder
    parent_folder = client.find_by_inventory_path([datacenter_name, 'vm', parent_folder_name])
    parent_folder.create_folder('lifecycle_tests') if parent_folder
  end

  def run_vsphere_cpi(json)
    bin_path = File.expand_path('../../../bin/vsphere_cpi', __FILE__)
    stdout, stderr, exit_status = Open3.capture3("#{bin_path} #{@config_path}", stdin_data: JSON.dump(json))
    raise "Failure running vsphere cpi #{stderr}" unless exit_status.success?
    stdout
  end

  def external_cpi_response(method, *arguments)
    request = {
      'method' => method,
      'arguments' => arguments,
      'context' => {
        'director_uuid' => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'
      }
    }

    response = JSON.load(run_vsphere_cpi(request))

    raise 'Failure to parse response' unless response
    response
  end

  def external_cpi_result(method, *arguments)
    response = external_cpi_response(method, *arguments)
    response['result']
  end

  # Thin integration test so
  # We have had coverage in the lifecycle_spec
  describe 'getting vms' do
    it 'is successful' do
      json = {
        'method' => 'has_vm',
        'arguments' => ['1234567'],
        'context' => { 'director_uuid' => 'abc' }
      }
      output = run_vsphere_cpi(json)
      expect(output).to match /"result":false,"error":null,"log":".*Request.*"}/
    end
  end
end
