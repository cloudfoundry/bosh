# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::TagManager do
  let(:server) { double('server', :id => 'i-foobar') }
  let(:metadata) { double("metadata") }

  it 'should trim key and value length' do
    expect(server).to receive(:metadata).and_return(metadata)
    expect(metadata).to receive(:update) do |parms|
      expect(parms.size).to eq(1)
      expect(parms.keys.first.size).to eq(255)
      expect(parms.values.first.size).to eq(255)
    end

    Bosh::OpenStackCloud::TagManager.tag(server, 'x'*256, 'y'*256)
  end

  it 'should do nothing if key is nil' do
    expect(server).not_to receive(:metadata)
    Bosh::OpenStackCloud::TagManager.tag(server, nil, 'value')
  end

  it 'should do nothing if value is nil' do
    expect(server).not_to receive(:metadata)
    Bosh::OpenStackCloud::TagManager.tag(server, 'key', nil)
  end

end