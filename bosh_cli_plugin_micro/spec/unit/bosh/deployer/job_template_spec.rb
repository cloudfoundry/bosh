require 'spec_helper'
require 'bosh/deployer/job_template'
require 'blobstore_client/base'

module Bosh::Deployer
  describe JobTemplate do
    subject { JobTemplate.new(template_spec, blobstore) }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient', get: nil) }
    let(:template_spec) do
      {
        'name' => 'fake-template-name',
        'version' => 'fake-version',
        'sha1' => 'fake-sha1',
        'blobstore_id' => 'fake-blob-id',
      }
    end

    describe '#initialize' do
      its(:name) { should eq('fake-template-name') }
      its(:version) { should eq('fake-version') }
      its(:sha1) { should eq('fake-sha1') }
      its(:blobstore_id) { should eq('fake-blob-id') }
    end

    describe '#download_blob' do
      let(:open_temp_file) { double('IO') }

      before do
        allow(SecureRandom).to receive(:uuid).and_return('fake-uuid')
        allow(Dir).to receive(:tmpdir).and_return('/path/to/tmp/dir')
        allow(File).to receive(:open).and_yield(open_temp_file)
      end

      it 'downloads the blob to a temporary location and returns path' do
        expect(subject.download_blob).to eq('/path/to/tmp/dir/template-fake-uuid')

        expect(blobstore).to have_received(:get).with('fake-blob-id', open_temp_file)
        expect(File).to have_received(:open).with('/path/to/tmp/dir/template-fake-uuid', 'w')
      end

      context 'when blobstore returns a `Could not fetch object` exception' do
        it 'raises a FetchError exception' do
          allow(blobstore).to receive(:get).and_raise(
                                Bosh::Blobstore::BlobstoreError,
                                'Could not fetch object ...',
                              )

          expect { subject.download_blob }.to raise_error(JobTemplate::FetchError)
        end
      end

      context 'when blobstore returns any other exception' do
        it 'raises original exception' do
          allow(blobstore).to receive(:get).and_raise(Bosh::Blobstore::BlobstoreError, 'Oops')

          expect { subject.download_blob }.to raise_error(Bosh::Blobstore::BlobstoreError, 'Oops')
        end
      end
    end
  end
end
