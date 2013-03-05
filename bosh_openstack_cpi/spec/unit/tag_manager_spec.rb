# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::TagManager do
  let(:server) { double('server', :id => 'i-foobar') }
  let(:metadata) { double("metadata") }

  it 'should trim key and value length' do
    server.should_receive(:metadata).and_return(metadata)
    metadata.should_receive(:update) do |parms|
      parms.size.should == 1
      parms.keys.first.size.should == 255
      parms.values.first.size.should == 255
    end

    Bosh::OpenStackCloud::TagManager.tag(server, 'x'*256, 'y'*256)
  end

  it 'should set metadata with a nil value' do
    server.should_receive(:metadata).and_return(metadata)
    metadata.should_receive(:update) do |parms|
      parms.size.should == 1
      parms.keys.first.should == "deployment"
      parms.values.first.should == ""
    end

    Bosh::OpenStackCloud::TagManager.tag(server, "deployment", nil)
  end

end