require 'spec_helper'

describe Bosh::AwsCloud::Cloud do

  before(:each) do
    @registry = mock_registry
  end

  it 'attaches EC2 volume to an instance' do
    instance = double('instance', :id => 'i-test')
    volume = double('volume', :id => 'v-foobar')
    attachment = double('attachment', :device => '/dev/sdf')

    cloud = mock_cloud do |ec2|
      expect(ec2.instances).to receive(:[]).with('i-test').and_return(instance)
      expect(ec2.volumes).to receive(:[]).with('v-foobar').and_return(volume)
    end

    expect(volume).to receive(:attach_to).
      with(instance, '/dev/sdf').and_return(attachment)

    expect(instance).to receive(:block_device_mappings).and_return({})

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
    instance = double('instance', :id => 'i-test')
    volume = double('volume', :id => 'v-foobar')
    attachment = double('attachment', :device => '/dev/sdh')

    cloud = mock_cloud do |ec2|
      expect(ec2.instances).to receive(:[]).with('i-test').and_return(instance)
      expect(ec2.volumes).to receive(:[]).with('v-foobar').and_return(volume)
    end

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
    instance = double('instance', :id => 'i-test')
    volume = double('volume', :id => 'v-foobar')
    attachment = double('attachment', :device => '/dev/sdh')

    cloud = mock_cloud do |ec2|
      expect(ec2.instances).to receive(:[]).with('i-test').and_return(instance)
      expect(ec2.volumes).to receive(:[]).with('v-foobar').and_return(volume)
    end

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
    instance = double('instance', :id => 'i-test')
    volume = double('volume', :id => 'v-foobar')

    cloud = mock_cloud do |ec2|
      expect(ec2.instances).to receive(:[]).with('i-test').and_return(instance)
      expect(ec2.volumes).to receive(:[]).with('v-foobar').and_return(volume)
    end

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

end
