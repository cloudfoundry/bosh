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

  before do
    delegate = double('delegate', logger: Logger.new(STDOUT))
    delegate.stub(:task_checkpoint)
    Bosh::Clouds::Config.configure(delegate)
    Bosh::AwsCloud::RegistryClient.stub(:new).and_return(double('registry').as_null_object)

    @instance_id = nil
    @volume_id = nil
  end

  after do
    # TODO detach volume if still attached (in case of test failure)
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

    vm_metadata = {:job => 'cpi_spec', :index => '0'}
    cpi.set_vm_metadata(@instance_id, vm_metadata)

    @volume_id = cpi.create_disk(2048, @instance_id)
    @volume_id.should_not be_nil

    cpi.attach_disk(@instance_id, @volume_id)

    snapshot_id = cpi.snapshot_disk(@volume_id)
    snapshot_id.should_not be_nil

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
