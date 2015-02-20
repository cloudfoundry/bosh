require 'spec_helper'

describe Bosh::AwsCloud::Cloud, '#set_vm_metadata' do
  let(:instance) { double('instance', :id => 'i-foobar') }

  before :each do
    @cloud = mock_cloud(mock_cloud_options['properties']) do |ec2|
      allow(ec2.instances).to receive(:[]).with('i-foobar').and_return(instance)
    end
  end

  it 'should add new tags for regular jobs' do
    metadata = {:job => 'job', :index => 'index'}

    expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(instance, :job, 'job')
    expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(instance, :index, 'index')
    expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(instance, 'Name', 'job/index')

    @cloud.set_vm_metadata('i-foobar', metadata)
  end

  it 'should add new tags for compiling jobs' do
    metadata = {:compiling => 'linux'}

    expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(instance, :compiling, 'linux')
    expect(Bosh::AwsCloud::TagManager).to receive(:tag).with(instance, 'Name', 'compiling/linux')

    @cloud.set_vm_metadata('i-foobar', metadata)
  end

end
