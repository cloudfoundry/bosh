# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::TagManager do
  let(:server) { double('server', :id => 'i-foobar', :class => Fog::Compute::Cloudstack::Server) }
  let(:metadata) { double("metadata") }

  before :each do
    stub_const('Fog::Compute::Cloudstack::Server', double("server"))
    stub_const('Fog::Compute::Cloudstack::Image', double("image"))
    stub_const('Fog::Compute::Cloudstack::Volume', double("volume"))
    stub_const('Fog::Compute::Cloudstack::Snapshot', double("snapshot"))
  end

  it 'should trim key and value length' do
    compute = double("compute")
    compute.should_receive(:create_tags) do |params|
      params["tags[0].key"].size.should == 255
      params["tags[0].value"].size.should == 255
      params["resourceids"].should == 'i-foobar'
      params["resourcetype"].should  == 'userVm'
    end
    server.should_receive(:service).and_return(compute)

    Bosh::CloudStackCloud::TagManager.tag(server, 'x'*256, 'y'*256)
  end

  it 'should raise error if unsupported taggable given' do
    server = double('server', :id => 'i-foobar', :class => Class.new)
    expect {
      Bosh::CloudStackCloud::TagManager.tag(server, 'foo', 'bar')
    }.to raise_error(Bosh::Clouds::CloudError, /Resource type `.*?' is not supported/)
  end

  it 'should do nothing if key is nil' do
    server.should_not_receive(:metadata)
    Bosh::CloudStackCloud::TagManager.tag(server, nil, 'value')
  end

  it 'should do nothing if value is nil' do
    server.should_not_receive(:metadata)
    Bosh::CloudStackCloud::TagManager.tag(server, 'key', nil)
  end

end
