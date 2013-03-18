require 'spec_helper'

describe Bosh::AwsCloud::TagManager do
  let(:instance) { double('instance', :id => 'i-xxxxxxx') }

  it 'should trim key and value length' do
    instance.should_receive(:add_tag) do |key, options|
      key.size.should == 127
      options[:value].size.should == 255
    end

    Bosh::AwsCloud::TagManager.tag(instance, 'x'*128, 'y'*256)
  end

  it 'should retry tagging when the tagged object is not found' do
    Bosh::AwsCloud::TagManager.stub(:sleep)

    instance.should_receive(:add_tag).exactly(3).times do
      @count ||= 0
      if @count < 2
        @count += 1
        raise AWS::EC2::Errors::InvalidAMIID::NotFound
      end
    end

    Bosh::AwsCloud::TagManager.tag(instance, 'key', 'value')
  end
end
