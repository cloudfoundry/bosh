require 'spec_helper'
require 'digest'
require 'bosh/dev/upload_adapter'
require 'bosh/stemcell/os_image_uploader'

describe Bosh::Stemcell::OsImageUploader do
  subject(:uploader) { described_class.new(digester: digester, adapter: adapter) }

  let(:digester) { class_double('Digest::SHA256', file: file_digest) }
  let(:file_digest) { instance_double('Digest::SHA256', hexdigest: 'hash') }

  let(:adapter) { instance_double('Bosh::Dev::UploadAdapter') }

  describe '#upload' do
    it 'uploads the os image keyed by its hash and returns its hash' do
      expect(digester).to receive(:file).with('/some/image.tgz')
      expect(adapter).to receive(:upload).with(
        bucket_name: 'some-bucket',
        key: 'hash',
        body: '/some/image.tgz',
        public: true,
      )

      expect(uploader.upload('some-bucket', '/some/image.tgz')).to eq('hash')
    end
  end
end
