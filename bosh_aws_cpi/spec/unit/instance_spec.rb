require 'spec_helper'
require 'logger'
require 'bosh/registry/client'

describe Bosh::AwsCloud::Instance do
  subject(:instance) { described_class.new(aws_instance, registry, elb, logger) }
  let(:aws_instance) { instance_double('AWS::EC2::Instance', id: instance_id) }
  let(:registry) { instance_double('Bosh::Registry::Client', :update_settings => nil) }
  let(:elb) { double('AWS::ELB') }
  let(:logger) { Logger.new('/dev/null') }

  let(:instance_id) { 'fake-id' }

  describe '#id' do
    it('returns instance id') { expect(instance.id).to eq(instance_id) }
  end

  describe '#elastic_ip' do
    it 'returns elastic IP' do
      expect(aws_instance).to receive(:elastic_ip).and_return('fake-ip')
      expect(instance.elastic_ip).to eq('fake-ip')
    end
  end

  describe '#associate_elastic_ip' do
    it 'propagates associate_elastic_ip' do
      expect(aws_instance).to receive(:associate_elastic_ip).with('fake-new-ip')
      instance.associate_elastic_ip('fake-new-ip')
    end
  end

  describe '#disassociate_elastic_ip' do
    it 'propagates disassociate_elastic_ip' do
      expect(aws_instance).to receive(:disassociate_elastic_ip)
      instance.disassociate_elastic_ip
    end
  end

  describe '#exists?' do
    it 'returns false if instance does not exist' do
      expect(aws_instance).to receive(:exists?).and_return(false)
      expect(instance.exists?).to be(false)
    end

    it 'returns true if instance does exist' do
      expect(aws_instance).to receive(:exists?).and_return(true)
      expect(aws_instance).to receive(:status).and_return(:running)
      expect(instance.exists?).to be(true)
    end

    it 'returns false if instance exists but is terminated' do
      expect(aws_instance).to receive(:exists?).and_return(true)
      expect(aws_instance).to receive(:status).and_return(:terminated)
      expect(instance.exists?).to be(false)
    end
  end

  describe '#terminate' do
    it 'should terminate an instance given the id' do
      allow(instance).to receive(:remove_from_load_balancers).ordered
      expect(aws_instance).to receive(:terminate).with(no_args).ordered
      expect(registry).to receive(:delete_settings).with(instance_id).ordered

      expect(Bosh::AwsCloud::ResourceWait).to receive(:for_instance).
        with(instance: aws_instance, state: :terminated).ordered

      instance.terminate
    end

    context 'when instance was deleted in AWS and no longer exists (showing in AWS console)' do
      before do
        # AWS returns NotFound error if instance no longer exists in AWS console
        # (This could happen when instance was deleted manually and BOSH is not aware of that)
        allow(aws_instance).to receive(:terminate).
          with(no_args).and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound)
      end

      it 'raises Bosh::Clouds::VMNotFound but still removes settings from registry' do
        expect(registry).to receive(:delete_settings).with(instance_id)

        expect {
          instance.terminate
        }.to raise_error(Bosh::Clouds::VMNotFound, "VM `#{instance_id}' not found")
      end
    end

    context 'when instance is already terminated when bosh checks for the state' do
      before do
        # AWS returns NotFound error if instance no longer exists in AWS console
        # (This could happen when instance was deleted very quickly and BOSH didn't catch the terminated state)
        allow(aws_instance).to receive(:terminate).with(no_args).ordered
      end

      it 'logs a message and considers the instance to be terminated' do
        expect(registry).to receive(:delete_settings).with(instance_id)

        allow(Bosh::AwsCloud::ResourceWait).to receive(:task_checkpoint)

        allow(aws_instance).to receive(:status).
                                   with(no_args).and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound)

        expect(logger).to receive(:debug).with("Failed to find terminated instance '#{instance_id}' after deletion: #{AWS::EC2::Errors::InvalidInstanceID::NotFound.new.inspect}")

        instance.terminate
      end
    end

    describe 'fast path deletion' do
      it 'deletes the instance without waiting for confirmation of termination' do
        allow(aws_instance).to receive(:terminate).ordered
        allow(registry).to receive(:delete_settings).ordered
        expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(aws_instance, "Name", "to be deleted").ordered
        instance.terminate(true)
      end
    end
  end

  describe '#reboot' do
    it 'reboots the instance' do
      expect(aws_instance).to receive(:reboot).with(no_args)
      instance.reboot
    end
  end

  describe '#attach_to_load_balancers' do
    before { allow(elb).to receive(:load_balancers).and_return(load_balancers) }
    let(:load_balancers) { { 'fake-lb1-id' => load_balancer1, 'fake-lb2-id' => load_balancer2 } }
    let(:load_balancer1) { instance_double('AWS::ELB::LoadBalancer', instances: lb1_instances) }
    let(:lb1_instances) { instance_double('AWS::ELB::InstanceCollection') }
    let(:load_balancer2) { instance_double('AWS::ELB::LoadBalancer', instances: lb2_instances) }
    let(:lb2_instances) { instance_double('AWS::ELB::InstanceCollection') }

    it 'attaches the instance to the list of load balancers' do
      expect(lb1_instances).to receive(:register).with(aws_instance)
      expect(lb2_instances).to receive(:register).with(aws_instance)
      instance.attach_to_load_balancers(%w(fake-lb1-id fake-lb2-id))
    end
  end
end
