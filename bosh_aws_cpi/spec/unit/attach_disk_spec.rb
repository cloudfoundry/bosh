require 'spec_helper'

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  let(:instance) { double('instance', :id => 'i-test') }
  let(:volume) { double('volume', :id => 'v-foobar') }

  let(:cloud) do
    mock_cloud do |ec2|
      allow(ec2.instances).to receive(:[]).with('i-test').and_return(instance)
      allow(ec2.volumes).to receive(:[]).with('v-foobar').and_return(volume)
    end
  end

  before { allow(instance).to receive(:block_device_mappings).and_return({}) }

  it 'attaches EC2 volume to an instance' do
    attachment = double('attachment', :device => '/dev/sdf')

    expect(volume).to receive(:attach_to).
      with(instance, '/dev/sdf').and_return(attachment)

    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_attachment).with(attachment: attachment, state: :attached)

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sdf'
        }
      }
    }

    expect(@registry).to receive(:read_settings).
      with('i-test').
      and_return(old_settings)

    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  it 'picks available device name' do
    attachment = double('attachment', :device => '/dev/sdh')

    expect(instance).to receive(:block_device_mappings).
      and_return({ '/dev/sdf' => 'foo', '/dev/sdg' => 'bar'})

    expect(volume).to receive(:attach_to).
      with(instance, '/dev/sdh').and_return(attachment)

    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_attachment).with(attachment: attachment, state: :attached)

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sdh'
        }
      }
    }

    expect(@registry).to receive(:read_settings).
      with('i-test').
      and_return(old_settings)

    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  it 'picks available device name' do
    attachment = double('attachment', :device => '/dev/sdh')

    expect(instance).to receive(:block_device_mappings).
      and_return({ '/dev/sdf' => 'foo', '/dev/sdg' => 'bar'})

    expect(volume).to receive(:attach_to).
      with(instance, '/dev/sdh').and_return(attachment)

    allow(Bosh::AwsCloud::ResourceWait).to receive(:for_attachment).with(attachment: attachment, state: :attached)

    old_settings = { 'foo' => 'bar'}
    new_settings = {
      'foo' => 'bar',
      'disks' => {
        'persistent' => {
          'v-foobar' => '/dev/sdh'
        }
      }
    }

    expect(@registry).to receive(:read_settings).
      with('i-test').
      and_return(old_settings)

    expect(@registry).to receive(:update_settings).with('i-test', new_settings)

    cloud.attach_disk('i-test', 'v-foobar')
  end

  it 'raises an error when sdf..sdp are all reserved' do
    all_mappings = ('f'..'p').inject({}) do |hash, char|
      hash["/dev/sd#{char}"] = 'foo'
      hash
    end

    expect(instance).to receive(:block_device_mappings).
      and_return(all_mappings)

    expect {
      cloud.attach_disk('i-test', 'v-foobar')
    }.to raise_error(Bosh::Clouds::CloudError, /too many disks attached/)
  end

  context 'when aws returns IncorrectState' do
    before { allow(Kernel).to receive(:sleep) }

    before do
      allow(volume).to receive(:attach_to).
          with(instance, '/dev/sdf').and_raise AWS::EC2::Errors::IncorrectState
    end

    it 'retries 15 times every 1 sec' do
      expect(volume).to receive(:attach_to).exactly(15).times
      expect {
        cloud.attach_disk('i-test', 'v-foobar')
      }.to raise_error Bosh::Clouds::CloudError, /AWS::EC2::Errors::IncorrectState/
    end
  end

  context 'when aws returns VolumeInUse' do
    before { allow(Kernel).to receive(:sleep) }

    before do
      allow(volume).to receive(:attach_to).
          with(instance, '/dev/sdf').and_raise AWS::EC2::Errors::VolumeInUse
    end

    it 'retries default number of attempts' do
      expect(volume).to receive(:attach_to).exactly(
          Bosh::AwsCloud::ResourceWait::DEFAULT_WAIT_ATTEMPTS).times

      expect {
        cloud.attach_disk('i-test', 'v-foobar')
      }.to raise_error AWS::EC2::Errors::VolumeInUse
    end
  end

  context 'when aws returns RequestLimitExceeded' do
    before { allow(Kernel).to receive(:sleep) }

    before do
      allow(volume).to receive(:attach_to).
          with(instance, '/dev/sdf').and_raise AWS::EC2::Errors::RequestLimitExceeded
    end

    it 'retries default wait attempts' do
      expect(volume).to receive(:attach_to).exactly(
          Bosh::AwsCloud::ResourceWait::DEFAULT_WAIT_ATTEMPTS).times

      expect {
        cloud.attach_disk('i-test', 'v-foobar')
      }.to raise_error AWS::EC2::Errors::RequestLimitExceeded
    end
  end
end
