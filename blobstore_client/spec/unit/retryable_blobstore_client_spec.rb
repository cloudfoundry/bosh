require 'spec_helper'

module Bosh::Blobstore
  describe RetryableBlobstoreClient do
    subject { described_class.new(wrapped_client, retryable) }
    let(:wrapped_client) { instance_double('Bosh::Blobstore::BaseClient') }
    let(:retryable)      { Bosh::Retryable.new(tries: 2, sleep: 0, on: [BlobstoreError]) }

    it_implements_base_client_interface
    it_calls_wrapped_client_methods(except: [:get])

    describe '#get' do
      let(:file) { Tempfile.new('fake-file') }

      it 'calls wrapped client with all given arguments' do
        options = double('fake-options')
        expect(wrapped_client).to receive(:get).with('fake-id', file, options)
        subject.get('fake-id', file, options)
      end

      it 'returns downloaded file if no file is given' do
        returned_file = double('fake-file')
        expect(wrapped_client)
          .to receive(:get)
          .with('fake-id', nil, {})
          .and_return(returned_file)
        expect(subject.get('fake-id', nil)).to eq(returned_file)
      end

      it 'propagates errors raised by wrapped client' do
        error = Exception.new('fake-wrapped-client-error')
        expect(wrapped_client).to receive(:get).and_raise(error)
        expect {
          subject.get('fake-id', file)
        }.to raise_error(error)
      end

      context 'when download failed and then succeeded' do
        error = BlobstoreError.new('fake-wrapped-client-error')

        context 'when file is given explicitly' do
          it 'calls wrapped client multiple times and returns successfully' do
            expect(wrapped_client).to receive(:get).ordered.and_raise(error)
            expect(wrapped_client).to receive(:get).ordered.with('fake-id', file, {})
            expect { subject.get('fake-id', file) }.to_not raise_error
          end
        end

        context 'when file is not given explicitly' do
          it 'calls wrapped client multiple times and returns successfully' do
            expect(wrapped_client).to receive(:get).ordered.and_raise(error)
            expect(wrapped_client).to receive(:get).ordered.with('fake-id', nil, {})
            expect { subject.get('fake-id', nil) }.to_not raise_error
          end
        end
      end

      context 'when number tries exceeded and downloading still failed' do
        error1 = BlobstoreError.new('fake-wrapped-client-error1')
        error2 = BlobstoreError.new('fake-wrapped-client-error2')

        context 'when file is given explicitly' do
          it 'raises last BlobstoreError' do
            expect(wrapped_client).to receive(:get).ordered.and_raise(error1)
            expect(wrapped_client).to receive(:get).ordered.and_raise(error2)
            expect {
              subject.get('fake-id', file)
            }.to raise_error(/fake-wrapped-client-error2/)
          end
        end

        context 'when file is not given explicitly' do
          it 'raises last BlobstoreError ' do
            expect(wrapped_client).to receive(:get).ordered.and_raise(error1)
            expect(wrapped_client).to receive(:get).ordered.and_raise(error2)
            expect {
              subject.get('fake-id', nil)
            }.to raise_error(/fake-wrapped-client-error2/)
          end
        end
      end
    end
  end
end
