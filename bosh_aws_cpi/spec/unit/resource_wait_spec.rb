require 'spec_helper'

describe Bosh::AwsCloud::ResourceWait do
  before { Kernel.stub(:sleep) }
  before { described_class.stub(:task_checkpoint) }

  describe '.for_instance' do
    let(:instance) { double(AWS::EC2::Instance, id: 'i-1234') }

    context 'deletion' do
      it 'should wait until the state is terminated' do
        instance.should_receive(:status).and_return(:shutting_down)
        instance.should_receive(:status).and_return(:shutting_down)
        instance.should_receive(:status).and_return(:terminated)

        described_class.for_instance(instance: instance, state: :terminated)
      end
    end

    context 'creation' do
      context 'when EC2 fails to find an instance' do
        it 'should wait until the state is running' do
          instance.should_receive(:status).and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound)
          instance.should_receive(:status).and_return(:pending)
          instance.should_receive(:status).and_return(:running)

          described_class.for_instance(instance: instance, state: :running)
        end
      end

      context 'when resource is not found' do
        it 'should wait until the state is running' do
          instance.should_receive(:status).and_raise(AWS::Core::Resource::NotFound)
          instance.should_receive(:status).and_return(:pending)
          instance.should_receive(:status).and_return(:running)

          described_class.for_instance(instance: instance, state: :running)
        end
      end

      it 'should fail if AWS terminates the instance' do
        instance.should_receive(:status).and_return(:pending)
        instance.should_receive(:status).and_return(:pending)
        instance.should_receive(:status).and_return(:terminated)

        expect {
          described_class.for_instance(instance: instance, state: :running)
        }.to raise_error Bosh::Clouds::VMCreationFailed
      end
    end
  end

  describe '.for_attachment' do
    let(:volume) { double(AWS::EC2::Volume, id: 'vol-1234') }
    let(:instance) { double(AWS::EC2::Instance, id: 'i-5678') }
    let(:attachment) { double(AWS::EC2::Attachment, volume: volume, instance: instance, device: '/dev/sda1') }

    context 'attachment' do
      it 'should wait until the state is attached' do
        attachment.should_receive(:status).and_return(:attaching)
        attachment.should_receive(:status).and_return(:attached)

        described_class.for_attachment(attachment: attachment, state: :attached)
      end

      it 'should retry when AWS::Core::Resource::NotFound is raised' do
        attachment.should_receive(:status).and_raise(AWS::Core::Resource::NotFound)
        attachment.should_receive(:status).and_return(:attached)

        described_class.for_attachment(attachment: attachment, state: :attached)
      end
    end

    context 'detachment' do
      it 'should wait until the state is detached' do
        attachment.should_receive(:status).and_return(:detaching)
        attachment.should_receive(:status).and_return(:detached)

        described_class.for_attachment(attachment: attachment, state: :detached)
      end

      it 'should consider AWS::Core::Resource::NotFound to be detached' do
        attachment.should_receive(:status).and_return(:detaching)
        attachment.should_receive(:status).and_raise(AWS::Core::Resource::NotFound)

        described_class.for_attachment(attachment: attachment, state: :detached)
      end
    end
  end

  describe '.for_volume' do
    let(:volume) { double(AWS::EC2::Volume, id: 'v-123') }

    context 'creation' do
      it 'should wait until the state is available' do
        volume.should_receive(:status).and_return(:creating)
        volume.should_receive(:status).and_return(:available)

        described_class.for_volume(volume: volume, state: :available)
      end

      it 'should raise an error on error state' do
        volume.should_receive(:status).and_return(:creating)
        volume.should_receive(:status).and_return(:error)

        expect {
          described_class.for_volume(volume: volume, state: :available)
        }.to raise_error Bosh::Clouds::CloudError, /state is error, expected available/
      end
    end

    context 'deletion' do
      it 'should wait until the state is deleted' do
        volume.should_receive(:status).and_return(:deleting)
        volume.should_receive(:status).and_return(:deleted)

        described_class.for_volume(volume: volume, state: :deleted)
      end

      it 'should consider InvalidVolume error to mean deleted' do
        volume.should_receive(:status).and_return(:deleting)
        volume.should_receive(:status).and_raise(AWS::EC2::Errors::InvalidVolume::NotFound)

        described_class.for_volume(volume: volume, state: :deleted)
      end
    end
  end

  describe '.for_snapshot' do
    let(:snapshot) { double(AWS::EC2::Snapshot, id: 'snap-123') }

    context 'creation' do
      it 'should wait until the state is completed' do
        snapshot.should_receive(:status).and_return(:pending)
        snapshot.should_receive(:status).and_return(:completed)

        described_class.for_snapshot(snapshot: snapshot, state: :completed)
      end

      it 'should raise an error if the state is error' do
        snapshot.should_receive(:status).and_return(:pending)
        snapshot.should_receive(:status).and_return(:error)

        expect {
          described_class.for_snapshot(snapshot: snapshot, state: :completed)
        }.to raise_error Bosh::Clouds::CloudError, /state is error, expected completed/
      end
    end
  end

  describe '.for_image' do
    let(:image) { double(AWS::EC2::Image, id: 'ami-123') }

    context 'creation' do
      it 'should wait until the state is available' do
        image.should_receive(:state).and_return(:pending)
        image.should_receive(:state).and_return(:available)

        described_class.for_image(image: image, state: :available)
      end

      it 'should wait if AWS::EC2::Errors::InvalidAMIID::NotFound raised' do
        image.should_receive(:state).and_raise(AWS::EC2::Errors::InvalidAMIID::NotFound)
        image.should_receive(:state).and_return(:pending)
        image.should_receive(:state).and_return(:available)

        described_class.for_image(image: image, state: :available)
      end

      it 'should raise an error if the state is failed' do
        image.should_receive(:state).and_return(:pending)
        image.should_receive(:state).and_return(:failed)

        expect {
          described_class.for_image(image: image, state: :available)
        }.to raise_error Bosh::Clouds::CloudError, /state is failed, expected available/
      end
    end

    context 'deletion' do
      it 'should wait until the state is deleted' do
        image.should_receive(:state).and_return(:available)
        image.should_receive(:state).and_return(:pending)
        image.should_receive(:state).and_return(:deleted)

        described_class.for_image(image: image, state: :deleted)
      end
    end
  end

  describe '.for_subnet' do
    let(:subnet) { double(AWS::EC2::Subnet, id: 'subnet-123') }

    context 'creation' do
      it 'should wait until the state is completed' do
        subnet.should_receive(:state).and_return(:pending)
        subnet.should_receive(:state).and_return(:available)

        described_class.for_subnet(subnet: subnet, state: :available)
      end
    end
  end

  describe 'catching errors' do
    it 'raises an error if the retry count is exceeded' do
      resource = double('resource', status: :bar)
      resource_arguments = {
        resource: resource,
        tries: 1,
        description: 'description',
        target_state: :foo
      }

      expect {
        subject.for_resource(resource_arguments) { |_| false }
      }.to raise_error(Bosh::Clouds::CloudError, /Timed out waiting/)
    end
  end

  describe '.sleep_callback' do
    it 'returns seconds to sleep interval capped at 32 seconds' do
      scb = described_class.sleep_callback('fake-time-test', 10)
      expected_times = [1, 2, 4, 8, 16, 32, 32, 32, 32, 32, 32]
      returned_times = (0..10).map { |try_number| scb.call(try_number, nil) }
      expect(returned_times).to eq(expected_times)
    end
  end

  describe '#for_resource' do
    let(:args) do
      {
        resource: double('fake-resource', status: nil),
        description: 'description',
        target_state: 'fake-target-state',
      }
    end

    it 'uses Bosh::Retryable with sleep_callback sleep setting' do
      sleep_cb = double('fake-sleep-callback')
      described_class.stub(:sleep_callback).and_return(sleep_cb)

      retryable = double('Bosh::Retryable', retryer: nil)
      Bosh::Retryable
        .should_receive(:new)
        .with(hash_including(sleep: sleep_cb))
        .and_return(retryable)

      subject.for_resource(args)
    end

    context 'when tries option is passed' do
      before { args[:tries] = 5 }

      it 'attempts passed number of times' do
        actual_attempts = 0
        expect {
          subject.for_resource(args) { actual_attempts += 1; false }
        }.to raise_error
        expect(actual_attempts).to eq(5)
      end
    end

    context 'when tries option is not passed' do
      it 'attempts DEFAULT_TRIES times to wait for ~25 minutes' do
        actual_attempts = 0
        expect {
          subject.for_resource(args) { actual_attempts += 1; false }
        }.to raise_error
        expect(actual_attempts).to eq(54)
      end
    end
  end
end
