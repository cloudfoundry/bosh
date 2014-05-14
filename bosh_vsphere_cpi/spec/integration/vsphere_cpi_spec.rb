require 'spec_helper'
require 'open3'
require 'tempfile'
require 'yaml'

describe VSphereCloud::Cloud do
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
    @db_path = Tempfile.new('vsphere_cpi.db').path
    @datacenter_name          = ENV.fetch('BOSH_VSPHERE_CPI_DATACENTER', 'BOSH_DC')
    @cluster                  = ENV.fetch('BOSH_VSPHERE_CPI_CLUSTER', 'BOSH_CL')
    @second_cluster           = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_CLUSTER', 'BOSH_CL2')

    host                      = ENV.fetch('BOSH_VSPHERE_CPI_HOST')
    user                      = ENV.fetch('BOSH_VSPHERE_CPI_USER')
    password                  = ENV.fetch('BOSH_VSPHERE_CPI_PASSWORD', '')
    resource_pool_name        = ENV.fetch('BOSH_VSPHERE_CPI_RESOURCE_POOL', 'ACCEPTANCE_RP')
    second_resource_pool_name = ENV.fetch('BOSH_VSPHERE_CPI_SECOND_RESOURCE_POOL', 'ACCEPTANCE_RP')

    client = VSphereCloud::Client.new("https://#{host}/sdk/vimService").tap do |client|
      client.login(user, password, 'en')
    end

    vm_folder_name = ENV.fetch('BOSH_VSPHERE_CPI_VM_FOLDER', 'ACCEPTANCE_BOSH_VMs')
    template_folder_name = ENV.fetch('BOSH_VSPHERE_CPI_TEMPLATE_FOLDER', 'ACCEPTANCE_BOSH_Templates')
    disk_folder_name = ENV.fetch('BOSH_VSPHERE_CPI_DISK_PATH', 'ACCEPTANCE_BOSH_Disks')

    prepare_tests_folder(client, @datacenter_name, vm_folder_name)
    prepare_tests_folder(client, @datacenter_name, template_folder_name)
    prepare_tests_folder(client, @datacenter_name, disk_folder_name)

    {
      'db' => {
        'database' => @db_path,
        'adapter' => 'sqlite',
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
              'name' => @datacenter_name,
              'vm_folder' => "#{vm_folder_name}/lifecycle_tests",
              'template_folder' => "#{template_folder_name}/lifecycle_tests",
              'disk_path' => "#{disk_folder_name}/lifecycle_tests",
              'datastore_pattern' => ENV.fetch('BOSH_VSPHERE_CPI_DATASTORE_PATTERN', 'jalapeno'),
              'persistent_datastore_pattern' => ENV.fetch('BOSH_VSPHERE_CPI_PERSISTENT_DATASTORE_PATTERN', 'jalapeno'),
              'allow_mixed_datastores' => true,
              'clusters' => [
                {
                  @cluster => { 'resource_pool' => resource_pool_name },
                },
                {
                  @second_cluster  => { 'resource_pool' => second_resource_pool_name }
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

  let(:network_spec) do
    {
      'static' => {
        'ip' => '169.254.1.1',
        'netmask' => '255.255.254.0',
        'cloud_properties' => { 'name' => vlan },
        'default' => ['dns', 'gateway'],
        'dns' => ['169.254.1.2'],
        'gateway' => '169.254.1.3'
      }
    }
  end
  let(:vlan) { ENV['BOSH_VSPHERE_VLAN'] || raise('Missing BOSH_VSPHERE_VLAN') }

  let(:original_resource_pool) {
    {
      'ram' => 1024,
      'disk' => 2048,
      'cpu' => 1,
    }
  }
  let(:resource_pool) { original_resource_pool }

  let(:disk_locality) { nil }

  def it_exercises_vm_lifecycle
    by 'creating vm' do
      @vm_id = external_cpi_result(:create_vm,
        'agent-007',
        @stemcell_id,
        resource_pool,
        network_spec,
        disk_locality,
        {'key' => 'value'}
      )

      expect(@vm_id).to_not be_nil
      expect(external_cpi_result(:has_vm, @vm_id)).to be(true)
    end

    and_by 'setting vm metadata' do
      metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0' }
      external_cpi_result(:set_vm_metadata, @vm_id, metadata)
    end

    and_by 'creating disk' do
      @disk_id = external_cpi_result(:create_disk, 2048, @vm_id)
      expect(@disk_id).to_not be_nil
    end

    and_by 'attaching disk' do
      external_cpi_result(:attach_disk, @vm_id, @disk_id)
    end

    and_by 'snapshotting disk' do
      expect(
        external_cpi_response(:snapshot_disk, @disk_id, {})['error']['type']
      ).to eq('Bosh::Clouds::NotImplemented')
    end

    and_by 'deleting snapshot' do
      expect(
        external_cpi_response(:delete_snapshot, 123)['error']['type']
      ).to eq('Bosh::Clouds::NotImplemented')
    end

    and_by 'detaching disk' do
      external_cpi_result(:detach_disk, @vm_id, @disk_id)
    end
  end

  describe 'running commands' do
    it 'ping-pongs' do
      json = {
        'method' => 'ping',
        'arguments' => [],
        'context' => { 'director_uuid' => 'abc' }
      }

      output = run_vsphere_cpi(json)
      expect(output).to match /{"result":"pong","error":null,"log":".*Request.*"}/
    end
  end

  describe 'migrations' do
    it 'runs migrations on database from config' do
      run_vsphere_cpi({})
      db = Sequel.sqlite(database: @db_path)
      result = db['SELECT * FROM vsphere_cpi_schema']
      expect(result.count).to be > 0
      expect(result.first[:filename]).to match(/initial/)
    end
  end

  describe 'lifecycle' do
    before { reset_vm_and_disk }
    after do
      external_cpi_result(:delete_vm, @vm_id) if @vm_id
      external_cpi_result(:delete_disk, @disk_id) if @disk_id
      reset_vm_and_disk
    end

    def reset_vm_and_disk
      @vm_id = nil
      @disk_id = nil
    end

    it 'should exercise the vm lifecycle without existing disks' do
      it_exercises_vm_lifecycle
    end

    context 'without existing disks and placer' do
      let(:first_cluster) { { @cluster => {} } }
      let(:second_cluster) { { @second_cluster => {} } }
      let(:resource_pool) do
        original_resource_pool.merge(
          'datacenters' => [{ 'name' => @datacenter_name, 'clusters' => [cluster]}]
        )
      end

      context 'when the first cluster is chosen' do
        let(:cluster) { first_cluster }

        it 'should exercise the vm lifecycle' do
          it_exercises_vm_lifecycle do
            vm = external_cpi_result(:get_vm_by_cid, @vm_id)
            vm_info = external_cpi_result(get_vm_host_info, vm)
            expect(vm_info['cluster']).to eq(@cluster)
          end
        end
      end

      context 'when the second cluster is chosen' do
        let(:cluster) { second_cluster }

        it 'should exercise the vm lifecycle' do
          it_exercises_vm_lifecycle do
            vm = external_cpi_result(:get_vm_by_cid, @vm_id)
            vm_info = external_cpi_result(get_vm_host_info, vm)
            expect(vm_info['cluster']).to eq(@second_cluster)
          end
        end
      end
    end

    context 'with existing disks' do
      let(:existing_volume_id) { external_cpi_result(:create_disk, 2048) }
      let(:disk_locality) { [existing_volume_id] }
      after { external_cpi_result(:delete_disk, existing_volume_id) if existing_volume_id }

      it 'should exercise the vm lifecycle' do
        it_exercises_vm_lifecycle
      end
    end
  end
end
