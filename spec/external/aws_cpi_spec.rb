# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'tempfile'
require 'cloud'
require 'bosh_aws_cpi'

describe Bosh::AwsCloud::Cloud do
  let(:cpi_options) do
    {
        'aws' => {
            'region' => 'us-east-1',
            'default_key_name' => 'bosh',
            'fast_path_delete' => 'yes',
            'access_key_id' => ENV['BOSH_AWS_ACCESS_KEY_ID'],
            'secret_access_key' => ENV['BOSH_AWS_SECRET_ACCESS_KEY'],
        },
        'registry' => {
            'endpoint' => 'fake',
            'user' => 'fake',
            'password' => 'fake'
        }
    }
  end

  let(:cpi) { described_class.new(cpi_options) }
  let(:ami) { 'ami-809a48e9' } # ubuntu-lucid-10.04-i386-server-20120221 on instance store
  let(:availability_zone) { 'us-east-1a' }
  let(:subnet_id) { ENV['BOSH_AWS_SUBNET_ID'] }

  before :all do
    unless ENV['BOSH_AWS_ACCESS_KEY_ID'] && ENV['BOSH_AWS_SECRET_ACCESS_KEY'] && ENV['BOSH_AWS_SUBNET_ID']
      raise "Missing env var.   You need 'BOSH_AWS_ACCESS_KEY_ID' 'BOSH_AWS_SECRET_ACCESS_KEY' and 'BOSH_AWS_SUBNET_ID' set."
    end
  end

  before do
    ec2 = AWS::EC2.new(
      access_key_id:     cpi_options['aws']['access_key_id'],
      secret_access_key: cpi_options['aws']['secret_access_key'],
    )
    ec2.instances.tagged('delete_me').each(&:terminate)

    delegate = double('delegate', logger: Logger.new(STDOUT))
    delegate.stub(:task_checkpoint)
    Bosh::Clouds::Config.configure(delegate)
    Bosh::Registry::Client.stub(:new).and_return(double('registry').as_null_object)

    @instance_id = nil
    @volume_id = nil
  end

  after do
    cpi.delete_vm(@instance_id) if @instance_id
    cpi.delete_disk(@volume_id) if @volume_id
  end

  def vm_lifecycle(ami, network_spec, disk_locality)
    @instance_id = cpi.create_vm(
        'agent-007',
        ami,
        {'instance_type' => 'm1.small'},
        network_spec,
        disk_locality,
        {'key' => 'value'})

    @instance_id.should_not be_nil

    # possible race condition here
    cpi.has_vm?(@instance_id).should be_true

    metadata = { deployment: 'deployment', job: 'cpi_spec', index: '0', delete_me: 'please' }
    cpi.set_vm_metadata(@instance_id, metadata)

    @volume_id = cpi.create_disk(2048, @instance_id)
    @volume_id.should_not be_nil

    cpi.attach_disk(@instance_id, @volume_id)

    metadata[:bosh_data] = 'bosh data'
    metadata[:instance_id] = 'instance'
    metadata[:agent_id] = 'agent'
    metadata[:director_name] = 'Director'
    metadata[:director_uuid] = '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'

    snapshot_id = cpi.snapshot_disk(@volume_id, metadata)
    snapshot_id.should_not be_nil

    snapshot = cpi.ec2.snapshots[snapshot_id]
    expect(snapshot.tags.device).to eq '/dev/sdf'
    expect(snapshot.tags.agent_id).to eq 'agent'
    expect(snapshot.tags.instance_id).to eq 'instance'
    expect(snapshot.tags.director_name).to eq 'Director'
    expect(snapshot.tags.director_uuid).to eq '6d06b0cc-2c08-43c5-95be-f1b2dd247e18'
    expect(snapshot.tags[:Name]).to eq 'deployment/cpi_spec/0/sdf'

    yield if block_given?

    cpi.delete_snapshot(snapshot_id)

    Bosh::Common.retryable(:tries=> 20, :on => Bosh::Clouds::DiskNotAttached, :sleep => lambda{|n,e| [2**(n-1), 30].min }) do
      cpi.detach_disk(@instance_id, @volume_id)
      true
    end
  end

  describe 'ec2' do
    let(:network_spec) do
      {
          'default' => {
              'type' => 'dynamic',
              'cloud_properties' => {}
          }
      }
    end

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        vm_lifecycle(ami, network_spec, [])
      end
    end

    context 'with existing disks' do
      before do
        @existing_volume_id = cpi.create_disk(2048)
      end

      after do
        cpi.delete_disk(@existing_volume_id) if @existing_volume_id
      end

      it 'should exercise the vm lifecycle' do
        vm_lifecycle(ami, network_spec, [@existing_volume_id])
      end

      it 'should list the disks' do
        vm_lifecycle(ami, network_spec, [@existing_volume_id]) do
          cpi.get_disks(@instance_id).should == [@volume_id]
        end
      end
    end
  end

  describe 'vpc' do
    let(:network_spec) do
      {
          'default' => {
              'type' => 'manual',
              'ip' => ip,
              'cloud_properties' => {'subnet' => subnet_id}
          }
      }
    end
    let(:ip) { '10.0.0.10' } # use different IP to avoid race condition

    context 'without existing disks' do
      it 'should exercise the vm lifecycle' do
        vm_lifecycle(ami, network_spec, [])
      end
    end
  end
end
