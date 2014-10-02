require 'spec_helper'
require 'tempfile'
require 'cloud'
require 'logger'

describe Bosh::OpenStackCloud::Cloud do
  before(:all) do
    @auth_url         = ENV['BOSH_OPENSTACK_AUTH_URL']    || raise('Missing BOSH_OPENSTACK_AUTH_URL')
    @username         = ENV['BOSH_OPENSTACK_USERNAME']    || raise('Missing BOSH_OPENSTACK_USERNAME')
    @api_key          = ENV['BOSH_OPENSTACK_API_KEY']     || raise('Missing BOSH_OPENSTACK_API_KEY')
    @tenant           = ENV['BOSH_OPENSTACK_TENANT']      || raise('Missing BOSH_OPENSTACK_TENANT')
    @stemcell_id      = ENV['BOSH_OPENSTACK_STEMCELL_ID'] || raise('Missing BOSH_OPENSTACK_STEMCELL_ID')
    @net_id           = ENV['BOSH_OPENSTACK_NET_ID']      || raise('Missing BOSH_OPENSTACK_NET_ID')
    @manual_ip        = ENV['BOSH_OPENSTACK_MANUAL_IP']   || raise('Missing BOSH_OPENSTACK_MANUAL_IP')
    @default_key_name = ENV.fetch('BOSH_OPENSTACK_DEFAULT_KEY_NAME', 'jenkins')

    # some environments may not have this set, and it isn't strictly necessary so don't raise if it isn't set
    @region = ENV['BOSH_OPENSTACK_REGION']
  end

  let(:boot_from_volume) { false }
  let(:boot_volume_type) { nil }
  let(:use_config_drive) { false }

  subject(:cpi) do
    described_class.new(
      'openstack' => {
        'auth_url' => @auth_url,
        'username' => @username,
        'api_key' => @api_key,
        'tenant' => @tenant,
        'region' => @region,
        'endpoint_type' => 'publicURL',
        'default_key_name' => @default_key_name,
        'default_security_groups' => %w(default),
        'wait_resource_poll_interval' => 5,
        'boot_from_volume' => boot_from_volume,
        'boot_volume_type' => boot_volume_type,
        'use_config_drive' => use_config_drive,
      },
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    )
  end

  before do
    delegate = double('delegate', task_checkpoint: nil, logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
  end

  before { allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger) }
  let(:logger) { Logger.new(STDERR) }

  before { allow(Bosh::Registry::Client).to receive(:new).and_return(double('registry').as_null_object) }

  describe 'dynamic network' do
    # even for dynamic networking we need to set the net_id as we may be in an environment
    # with multiple networks
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    context 'without existing disks' do
      it 'exercises the vm lifecycle' do
        vm_lifecycle(@stemcell_id, network_spec, [])
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = cpi.create_disk(2048, {}) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
        }.to_not raise_error
      end
    end
  end

  describe 'manual network' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @manual_ip,
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    context 'without existing disks' do
      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [])
        }.to_not raise_error
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = cpi.create_disk(2048, {}) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'exercises the vm lifecycle' do
        expect {
          vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
        }.to_not raise_error
      end
    end
  end

  context 'when booting from volume' do
    let(:boot_from_volume) { true }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @manual_ip,
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [])
      }.to_not raise_error
    end
  end

  context 'when booting from volume with a volume_type' do
    let(:boot_from_volume) { true }
    let(:boot_volume_type) { "foo" }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @manual_ip,
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [])
      }.to_not raise_error
    end
  end

  context 'when using cloud_properties' do
    let(:cloud_properties) { { 'type' => 'foo' } }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [], cloud_properties)
      }.to_not raise_error
    end
  end

  context 'when using config drive' do
    let(:use_config_drive) { true }

    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {
            'net_id' => @net_id
          }
        }
      }
    end

    it 'exercises the vm lifecycle' do
      expect {
        vm_lifecycle(@stemcell_id, network_spec, [])
      }.to_not raise_error
    end
  end

  def vm_lifecycle(stemcell_id, network_spec, disk_locality, cloud_properties = {})
    vm_id = create_vm(stemcell_id, network_spec, disk_locality)
    disk_id = create_disk(vm_id, cloud_properties)
    disk_snapshot_id = create_disk_snapshot(disk_id)
  rescue Exception => create_error
  ensure
    # create_error is in scope and possibly populated!
    run_all_and_raise_any_errors(create_error, [
      lambda { clean_up_disk_snapshot(disk_snapshot_id) },
      lambda { clean_up_disk(disk_id) },
      lambda { clean_up_vm(vm_id, network_spec) },
    ])
  end

  def create_vm(stemcell_id, network_spec, disk_locality)
    logger.info("Creating VM with stemcell_id=#{stemcell_id}")
    vm_id = cpi.create_vm(
      'agent-007',
      stemcell_id,
      { 'instance_type' => 'm1.small'},
      network_spec,
      disk_locality,
      { 'key' => 'value'}
    )
    expect(vm_id).to be

    logger.info("Checking VM existence vm_id=#{vm_id}")
    expect(cpi).to have_vm(vm_id)

    logger.info("Setting VM metadata vm_id=#{vm_id}")
    cpi.set_vm_metadata(vm_id, {
      :deployment => 'deployment',
      :job => 'openstack_cpi_spec',
      :index => '0',
    })

    vm_id
  end

  def clean_up_vm(vm_id, network_spec)
    if vm_id
      logger.info("Deleting VM vm_id=#{vm_id}")
      cpi.delete_vm(vm_id)

      logger.info("Checking VM existence vm_id=#{vm_id}")
      expect(cpi).to_not have_vm(vm_id)

      if network_spec['default']['type'] == 'manual'
        # Wait for manual IP to be released by the infrastructure
        # We have seen Piston take a couple minutes to release an IP address
        sleep 120
      end
    else
      logger.info('No VM to delete')
    end
  end

  def create_disk(vm_id, cloud_properties)
    logger.info("Creating disk for VM vm_id=#{vm_id}")
    disk_id = cpi.create_disk(2048, cloud_properties, vm_id)
    expect(disk_id).to be

    logger.info("Attaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
    cpi.attach_disk(vm_id, disk_id)

    logger.info("Detaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
    cpi.detach_disk(vm_id, disk_id)

    disk_id
  end

  def clean_up_disk(disk_id)
    if disk_id
      logger.info("Deleting disk disk_id=#{disk_id}")
      cpi.delete_disk(disk_id)
    else
      logger.info('No disk to delete')
    end
  end

  def create_disk_snapshot(disk_id)
    logger.info("Creating disk snapshot disk_id=#{disk_id}")
    disk_snapshot_id = cpi.snapshot_disk(disk_id, {
      :deployment => 'deployment',
      :job => 'openstack_cpi_spec',
      :index => '0',
      :instance_id => 'instance',
      :agent_id => 'agent',
      :director_name => 'Director',
      :director_uuid => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
    })
    expect(disk_snapshot_id).to be

    logger.info("Created disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
    disk_snapshot_id
  end

  def clean_up_disk_snapshot(disk_snapshot_id)
    if disk_snapshot_id
      logger.info("Deleting disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
      cpi.delete_snapshot(disk_snapshot_id)
    else
      logger.info('No disk snapshot to delete')
    end
  end

  def run_all_and_raise_any_errors(existing_errors, funcs)
    exceptions = Array(existing_errors)
    funcs.each do |f|
      begin
        f.call
      rescue Exception => e
        exceptions << e
      end
    end
    # Prints all exceptions but raises original exception
    exceptions.each { |e| logger.info("Failed with: #{e.inspect}\n#{e.backtrace.join("\n")}\n") }
    raise exceptions.first if exceptions.any?
  end
end
