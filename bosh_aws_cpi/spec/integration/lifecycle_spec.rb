require 'spec_helper'
require 'bosh/cpi/compatibility_helpers/delete_vm'
require 'tempfile'
require 'logger'
require 'cloud'

describe Bosh::AwsCloud::Cloud do
  before(:all) do
    @access_key_id     = ENV['BOSH_AWS_ACCESS_KEY_ID']       || raise("Missing BOSH_AWS_ACCESS_KEY_ID")
    @secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY']   || raise("Missing BOSH_AWS_SECRET_ACCESS_KEY")
    @subnet_id         = ENV['BOSH_AWS_SUBNET_ID']           || raise("Missing BOSH_AWS_SUBNET_ID")
    @manual_ip         = ENV['BOSH_AWS_LIFECYCLE_MANUAL_IP'] || raise("Missing BOSH_AWS_LIFECYCLE_MANUAL_IP")
  end

  let(:instance_type) { ENV.fetch('BOSH_AWS_INSTANCE_TYPE', 't2.small') }
  let(:ami) { ENV.fetch('BOSH_AWS_IMAGE_ID', 'ami-b66ed3de') }
  let(:vm_metadata) { { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' } }
  let(:disks) { [] }
  let(:network_spec) { {} }

  before { Bosh::Registry::Client.stub(new: double('registry').as_null_object) }

  # Use subject-bang because AWS SDK needs to be reconfigured
  # with a current test's logger before new AWS::EC2 object is created.
  # Reconfiguration happens via `AWS.config`.
  subject!(:cpi) do
    described_class.new(
      'aws' => {
        'region' => 'us-east-1',
        'default_key_name' => 'bosh',
        'fast_path_delete' => 'yes',
        'access_key_id' => @access_key_id,
        'secret_access_key' => @secret_access_key,
      },
      'registry' => {
        'endpoint' => 'fake',
        'user' => 'fake',
        'password' => 'fake'
      }
    )
  end

  before do
    AWS::EC2.new(
      access_key_id:     @access_key_id,
      secret_access_key: @secret_access_key,
    ).instances.tagged('delete_me').each(&:terminate)
  end

  before do
    Bosh::Clouds::Config.configure(
      double('delegate', task_checkpoint: nil, logger: Logger.new(STDOUT)))
  end

  before { Bosh::Clouds::Config.stub(logger: logger) }
  let(:logger) { Logger.new(STDERR) }

  before { @instance_id = nil }
  after  { cpi.delete_vm(@instance_id) if @instance_id }

  before { @volume_id = nil }
  after  { cpi.delete_disk(@volume_id) if @volume_id }

  extend Bosh::Cpi::CompatibilityHelpers

  # Pass in *real* previously terminated instance id
  # instead of just a made-up instance id
  # because AWS returns Malformed error
  # for instance ids that are not proper AWS hashed values.
  it_can_delete_non_existent_vm 'i-49f9f169'

  describe 'ec2' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'dynamic',
          'cloud_properties' => {}
        }
      }
    end

    describe 'VM lifecycle with light stemcells' do
      it 'exercises vm lifecycle with light stemcell' do
        expect {
          vm_lifecycle
        }.not_to raise_error
      end
    end

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        vm_lifecycle do |instance_id|
          volume_id = cpi.create_disk(2048, {}, instance_id)
          expect(volume_id).not_to be_nil

          cpi.attach_disk(instance_id, volume_id)

          snapshot_metadata = vm_metadata.merge(
            bosh_data: 'bosh data',
            instance_id: 'instance',
            agent_id: 'agent',
            director_name: 'Director',
            director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
          )

          snapshot_id = cpi.snapshot_disk(volume_id, snapshot_metadata)
          expect(snapshot_id).not_to be_nil

          snapshot = cpi.ec2.snapshots[snapshot_id]
          expect(snapshot.tags.device).to eq '/dev/sdf'
          expect(snapshot.tags.agent_id).to eq 'agent'
          expect(snapshot.tags.instance_id).to eq 'instance'
          expect(snapshot.tags.director_name).to eq 'Director'
          expect(snapshot.tags.director_uuid).to eq '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'

          expect(snapshot.tags[:Name]).to eq 'deployment/cpi_spec/0/sdf'

          cpi.delete_snapshot(snapshot_id)

          Bosh::Common.retryable(tries: 20, on: Bosh::Clouds::DiskNotAttached, sleep: lambda { |n, _| [2**(n-1), 30].min }) do
            cpi.detach_disk(instance_id, volume_id)
            true
          end
        end
      end
    end

    context 'with existing disks' do
      let!(:existing_volume_id) { cpi.create_disk(2048, {}) }
      let(:disks) { [existing_volume_id] }
      after  { cpi.delete_disk(existing_volume_id) if existing_volume_id }

      it 'should exercise the vm lifecycle' do
        vm_lifecycle
      end

      it 'should list the disks' do
        vm_lifecycle do |instance_id|
          volume_id = cpi.create_disk(2048, {}, instance_id)
          expect(volume_id).not_to be_nil

          cpi.attach_disk(instance_id, volume_id)
          expect(cpi.get_disks(instance_id)).to include(volume_id)

          Bosh::Common.retryable(tries: 20, on: Bosh::Clouds::DiskNotAttached, sleep: lambda { |n, _| [2**(n-1), 30].min }) do
            cpi.detach_disk(instance_id, volume_id)
            true
          end
        end
      end
    end
  end

  describe 'vpc' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => @manual_ip, # use different IP to avoid race condition
          'cloud_properties' => { 'subnet' => @subnet_id }
        }
      }
    end

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        vm_lifecycle
      end
    end
  end

  def vm_lifecycle
    stemcell_id = cpi.create_stemcell('/not/a/real/path', { 'ami' => { 'us-east-1' => ami } })
    instance_id = cpi.create_vm(
      nil,
      stemcell_id,
      { 'instance_type' => instance_type },
      network_spec,
      disks,
      {}
    )
    expect(instance_id).not_to be_nil

    expect(cpi.has_vm?(instance_id)).to be(true)

    cpi.set_vm_metadata(instance_id, vm_metadata)

    yield(instance_id) if block_given?
  ensure
    cpi.delete_vm(instance_id) if instance_id
    cpi.delete_stemcell(stemcell_id) if stemcell_id
  end
end
