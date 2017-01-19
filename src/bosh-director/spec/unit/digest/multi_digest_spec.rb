require 'spec_helper'

module Bosh::Director::Digest
  describe MultiDigest do
    context 'when sha1 of downloaded file matches expected sha1' do
      subject(:multi_digest) { MultiDigest.new(logger) }

      let(:file_path) { 'fake-file-path' }
      let(:multi_digest_path) { '/some/path/to/binary' }

      before do
        allow(Bosh::Director::Config).to receive(:verify_multidigest_path).and_return multi_digest_path
        allow(Open3).to receive(:capture3).with("#{multi_digest_path} verify-multi-digest fake-file-path 'expected-sha'").
          and_return(['foo', 'bar', process_status])
      end

      context 'logging' do
        let(:process_status) { instance_double('Process::Status', exitstatus: 0) }

        it 'logs the invocation' do
          expect(logger).to receive(:info).with(/Verifying file shasum with command: "#{multi_digest_path} verify-multi-digest fake-file-path 'expected-sha'"/)
          expect(logger).to receive(:info).with(/Shasum matched for file: 'fake-file-path' digest: 'expected-sha'/)
          subject.verify(file_path, 'expected-sha')
        end
      end

      context 'when expected sha is correct' do
        let(:process_status) { instance_double('Process::Status', exitstatus: 0) }

        it 'does not raise an error' do
          expect {
            subject.verify(file_path, 'expected-sha')
          }.to_not raise_error
        end
      end

      context 'when expected sha is incorrect' do
        let(:process_status) { instance_double('Process::Status', exitstatus: 1) }

        it 'does not raise an error' do
          expect {
            subject.verify(file_path, 'expected-sha')
          }.to raise_error(ShaMismatchError, 'bar')
        end
      end
    end
  end
end
