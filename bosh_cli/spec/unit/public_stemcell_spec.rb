require 'spec_helper'
require 'cli/public_stemcell'

module Bosh::Cli
  describe PublicStemcell do
    let(:properties) do
      {
        'url' => 'fake-url',
        'size' => 'fake-size',
        'sha1' => 'fake-sha1',
        'tags' => %w(fake-tag1 fake-tag2 fake-tag3),
      }
    end

    subject(:public_stemcell) do
      PublicStemcell.new('fake-name', properties)
    end

    its(:name) { should eq('fake-name') }
    its(:url) { should eq(properties['url']) }
    its(:size) { should eq(properties['size']) }
    its(:sha1) { should eq(properties['sha1']) }
    its(:tags) { should eq(properties['tags']) }
    its(:tag_names) { should eq('fake-tag1, fake-tag2, fake-tag3') }

    context 'when the public stemcell is not tagged' do
      before do
        properties['tags'] = nil
      end

      its(:tag_names) { should eq('') }
    end

    context 'when the public stemcell is tagged' do
      context 'with all the requested tags' do
        it { should be_tagged(['fake-tag1', 'fake-tag2']) }
      end

      context 'with some of the requested tags' do
        it { should_not be_tagged(['fake-tag3', 'fake-tag4']) }
      end
    end
  end
end
