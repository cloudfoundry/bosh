require 'spec_helper'

module Bosh::Blobstore
  describe Sha1VerifiableBlobstoreClient do
    subject { described_class.new(wrapped_client, per_spec_logger) }
    let(:wrapped_client) { instance_double('Bosh::Blobstore::BaseClient') }
    let(:multidigest_path) { 'some/path/to/binary' }

    it_calls_wrapped_client_methods(except: [:get])

    before do
      allow(Bosh::Director::Config).to receive(:verify_multidigest_path).and_return(multidigest_path)
    end

    describe '#get' do
      let(:file) { double('fake-file', path: 'fake-file-path') }

      it 'calls wrapped client with all given arguments' do
        options = { 'sha1' => 'fake-sha1', 'fake-key' => 'fake-value' }
        expect(wrapped_client).to receive(:get).with('fake-id', file, options)
        subject.get('fake-id', file, options)
      end

      it 'returns downloaded file if no file is given' do
        expect(wrapped_client)
          .to receive(:get)
          .with('fake-id', nil, {})
          .and_return(file)
        expect(subject.get('fake-id', nil, {})).to eq(file)
      end

      it 'propagates errors raised by wrapped client' do
        error = Exception.new('fake-wrapped-client-error')
        expect(wrapped_client).to receive(:get).and_raise(error)
        expect {
          subject.get('fake-id', file)
        }.to raise_error(error)
      end

      context 'when file download is finished' do
        before { allow(wrapped_client).to receive(:get) }

        context 'when sha1 of downloaded file matches expected sha1' do
          let(:process_status) { instance_double('Process::Status', exitstatus: 0) }

          before do
            allow(Open3).to receive(:capture3).with(multidigest_path, 'verify-multi-digest', 'fake-file-path', 'expectedsha1').
                and_return(['foo', 'bar', process_status])
          end

          context 'when expected sha1 is given in the options' do
            it 'does not raise an error' do
              expect {
                subject.get('fake-id', file, sha1: 'expectedsha1')
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
          let(:process_status) { instance_double('Process::Status', exitstatus: 1) }

          before do
            allow(Open3).to receive(:capture3).with(multidigest_path, 'verify-multi-digest', 'fake-file-path', 'expectedsha1').
                and_return(['foo', 'bar', process_status])
          end

          context 'when expected sha1 is given in the options' do
            it 'raises BlobstoreError' do
              expect {
                subject.get('fake-id', file, sha1: 'expectedsha1')
              }.to raise_error(
                Bosh::Blobstore::BlobstoreError, 'bar'
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
