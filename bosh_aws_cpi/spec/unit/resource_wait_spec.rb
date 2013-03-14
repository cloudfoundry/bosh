require 'spec_helper'

describe Bosh::AwsCloud::ResourceWait do

  before do
    Bosh::Common.stub(:sleep)
    Bosh::Clouds::Config.stub(:task_checkpoint)
    described_class.stub(:logger)
  end

  describe '#for_instance' do
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
      it 'should wait until the state is running' do
        instance.should_receive(:status).and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound)
        instance.should_receive(:status).and_return(:pending)
        instance.should_receive(:status).and_return(:running)

        described_class.for_instance(instance: instance, state: :running)
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

  describe '#for_attachment' do
    let(:attachment) { double(AWS::EC2::Attachment, to_s: 'a-1234') }

    context 'attachment' do
     it 'should wait until the state is attached' do
       attachment.should_receive(:status).and_return(:attaching)
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

  describe '#for_volume' do
    let(:volume) { double(AWS::EC2::Volume, id: 'v-123') }

    context 'creation' do
      it 'should wait until the state is available' do
        volume.should_receive(:status).and_return(:creating)
        volume.should_receive(:status).and_return(:available)

        described_class.for_volume(volume: volume, state: :available)
      end
      #:error

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

  describe '#for_snapshot' do
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

  describe '#for_image' do
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

  describe '#for_subnet' do
    let(:subnet) { double(AWS::EC2::Subnet, id: 'subnet-123') }

    context 'creation' do
      it 'should wait until the state is completed' do
        subnet.should_receive(:state).and_return(:pending)
        subnet.should_receive(:state).and_return(:available)

        described_class.for_subnet(subnet: subnet, state: :available)
      end
    end
  end
end