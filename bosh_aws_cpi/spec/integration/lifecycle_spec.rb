require 'spec_helper'
require 'tempfile'
require 'logger'
require 'cloud'

describe Bosh::AwsCloud::Cloud do
  before(:all) do
    @access_key_id     = ENV['BOSH_AWS_ACCESS_KEY_ID']     || raise("Missing BOSH_AWS_ACCESS_KEY_ID")
    @secret_access_key = ENV['BOSH_AWS_SECRET_ACCESS_KEY'] || raise("Missing BOSH_AWS_SECRET_ACCESS_KEY")
    @subnet_id         = ENV['BOSH_AWS_SUBNET_ID']         || raise("Missing BOSH_AWS_SUBNET_ID")
  end

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

  let(:ami) { 'ami-809a48e9' } # ubuntu-lucid-10.04-i386-server-20120221 on instance store

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
      it 'excercises vm lifecycle with light stemcell' do
        expect {
          stemcell_id = cpi.create_stemcell('/not/a/real/path', { 'ami' => { 'us-east-1' => 'ami-809a48e9' } })
          instance_id = cpi.create_vm(
            nil,
            stemcell_id,
            { 'instance_type' => 'm1.small' },
            network_spec,
            [],
            {}
          )
          vm_metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' }
          cpi.set_vm_metadata(instance_id, vm_metadata)
          cpi.delete_vm(instance_id)
          cpi.delete_stemcell(stemcell_id)
        }.not_to raise_error
      end
    end

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        @instance_id = cpi.create_vm(
          'agent-007',
          ami,
          { 'instance_type' => 'm1.small' },
          network_spec,
          [],
          { 'key' => 'value' }
        )

        expect(@instance_id).not_to be_nil

        # possible race condition here
        expect(cpi.has_vm?(@instance_id)).to be(true)

        vm_metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' }
        cpi.set_vm_metadata(@instance_id, vm_metadata)

        @volume_id = cpi.create_disk(2048, @instance_id)
        expect(@volume_id).not_to be_nil

        cpi.attach_disk(@instance_id, @volume_id)

        snapshot_metadata = vm_metadata.merge(
          bosh_data: 'bosh data',
          instance_id: 'instance',
          agent_id: 'agent',
          director_name: 'Director',
          director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
        )

        snapshot_id = cpi.snapshot_disk(@volume_id, snapshot_metadata)
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
          cpi.detach_disk(@instance_id, @volume_id)
          true
        end
      end
    end

    context 'with existing disks' do
      before { @existing_volume_id = cpi.create_disk(2048) }
      after  { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it 'should exercise the vm lifecycle' do
        @instance_id = cpi.create_vm(
          'agent-007',
          ami,
          { 'instance_type' => 'm1.small' },
          network_spec,
          [@existing_volume_id],
          { 'key' => 'value' }
        )

        expect(@instance_id).not_to be_nil

        # possible race condition here
        expect(cpi.has_vm?(@instance_id)).to be(true)

        metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' }
        cpi.set_vm_metadata(@instance_id, metadata)
      end

      it 'should list the disks' do
        @instance_id = cpi.create_vm(
          'agent-007',
          ami,
          { 'instance_type' => 'm1.small' },
          network_spec,
          [@existing_volume_id],
          { 'key' => 'value' }
        )

        expect(@instance_id).not_to be_nil

        # possible race condition here
        expect(cpi.has_vm?(@instance_id)).to be(true)

        metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' }
        cpi.set_vm_metadata(@instance_id, metadata)

        @volume_id = cpi.create_disk(2048, @instance_id)
        expect(@volume_id).not_to be_nil

        cpi.attach_disk(@instance_id, @volume_id)
        expect(cpi.get_disks(@instance_id)).to eq [@volume_id]

        Bosh::Common.retryable(tries: 20, on: Bosh::Clouds::DiskNotAttached, sleep: lambda { |n, _| [2**(n-1), 30].min }) do
          cpi.detach_disk(@instance_id, @volume_id)
          true
        end
      end
    end
  end

  describe 'vpc' do
    let(:network_spec) do
      {
        'default' => {
          'type' => 'manual',
          'ip' => '10.0.0.9', # use different IP to avoid race condition
          'cloud_properties' => { 'subnet' => @subnet_id }
        }
      }
    end

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        @instance_id = cpi.create_vm(
          'agent-007',
          ami,
          { 'instance_type' => 'm1.small' },
          network_spec,
          [],
          { 'key' => 'value' }
        )

        expect(@instance_id).not_to be_nil

        # possible race condition here
        expect(cpi.has_vm?(@instance_id)).to be(true)

        metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' }
        cpi.set_vm_metadata(@instance_id, metadata)
      end
    end
  end
end
