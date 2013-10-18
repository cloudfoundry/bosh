require 'spec_helper'

module Bosh::Blobstore
  describe Sha1VerifiableBlobstoreClient do
    describe '#get' do
      subject { described_class.new(wrapped_client) }
      let(:wrapped_client) { instance_double('Bosh::Blobstore::BaseClient') }

      let(:file) { double('fake-file', path: 'fake-file-path') }

      it 'calls wrapped client with all given arguments' do
        options = { 'sha1' => 'fake-sha1', 'fake-key' => 'fake-value' }
        wrapped_client.should_receive(:get).with('fake-id', file, options)
        subject.get('fake-id', file, options)
      end

      it 'returns downloaded file if no file is given' do
        wrapped_client
          .should_receive(:get)
          .with('fake-id', nil, {})
          .and_return(file)
        expect(subject.get('fake-id', nil, {})).to eq(file)
      end

      it 'propagates errors raised by wrapped client' do
        error = Exception.new('fake-wrapped-client-error')
        wrapped_client.should_receive(:get).and_raise(error)
        expect {
          subject.get('fake-id', file)
        }.to raise_error(error)
      end

      context 'when file download is finished' do
        before { wrapped_client.stub(:get) }

        context 'when sha1 of downloaded file matches expected sha1' do
          before { Digest::SHA1.stub(:file).with('fake-file-path').and_return(sha1_digest) }
          let(:sha1_digest) { instance_double('Digest::SHA1', hexdigest: 'expected-sha1') }

          context 'when expected sha1 is given in the options' do
            it 'does not raise an error' do
              expect {
                subject.get('fake-id', file, sha1: 'expected-sha1')
              }.to_not raise_error
            end
          end

          context 'when expected sha1 is not given in the options' do
            it 'does not raise an error' do
              expect {
                subject.get('fake-id', file)
              }.to_not raise_error
            end
          end
        end

        context 'when sha1 of downloaded file does not match expected sha1' do
          before { Digest::SHA1.stub(:file).with('fake-file-path').and_return(sha1_digest) }
          let(:sha1_digest) { instance_double('Digest::SHA1', hexdigest: 'actual-sha1') }

          context 'when expected sha1 is given in the options' do
            it 'raises BlobstoreError' do
              expect {
                subject.get('fake-id', file, sha1: 'expected-sha1')
              }.to raise_error(
                BlobstoreError,
                /sha1 mismatch expected=expected-sha1 actual=actual-sha1/,
              )
            end
          end

          context 'when expected sha1 is not given in the options' do
            it 'raises BlobstoreError' do
              expect {
                subject.get('fake-id', file)
              }.to_not raise_error
            end
          end
        end
      end

      context 'when options includes sha1 but it is nil' do
        it 'raises ArgumentError' do
          expect {
            subject.get('fake-id', file, sha1: nil)
          }.to raise_error(ArgumentError, /sha1 must not be nil/)
        end
      end
    end
  end
end
