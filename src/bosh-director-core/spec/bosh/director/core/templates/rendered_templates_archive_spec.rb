require 'spec_helper'
require 'bosh/director/core/templates/rendered_templates_archive'

module Bosh::Director::Core::Templates
  describe RenderedTemplatesArchive do
    subject { described_class.new('fake-blobstore-id', 'fake-sha1') }

    describe '#spec' do
      it 'returns blobstore_id and sha1' do
        expect(subject.spec).to eq(
                                  'blobstore_id' => 'fake-blobstore-id',
                                  'sha1' => 'fake-sha1',
                                )
      end
    end
  end
end
