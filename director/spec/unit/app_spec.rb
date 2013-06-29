require 'spec_helper'

describe Bosh::Director::App do
  let(:config) { Bosh::Director::Config.load_file(asset("test-director-config.yml")) }

  describe 'initialize' do
    it 'takes a Config' do
      described_class.new(config)
    end

    it 'establishes the singleton instance' do
      app = described_class.new(config)
      expect(described_class.instance).to be(app)
    end

    # This will go away when the legacy Config.configure() goes away
    it 'configures the legacy Config system' do
      BD::Config.should_receive(:configure).with(config.hash)
      described_class.new(config)
    end
  end

  describe '#blobstores' do
    subject { described_class.new(config) }

    it 'provides the blobstores' do
      expect(subject.blobstores).to be_a(Bosh::Director::Blobstores)
    end

  end
end