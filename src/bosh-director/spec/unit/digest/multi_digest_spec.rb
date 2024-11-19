require 'spec_helper'

module Bosh::Director::BoshDigest
  describe MultiDigest do
    context 'when sha1 of downloaded file matches expected sha1' do
      subject(:multi_digest) { MultiDigest.new(per_spec_logger) }
      let(:file_path) { 'fake-file-path' }
      let(:multi_digest_path) { '/some/path/to/binary' }

      before do
        allow(Bosh::Director::Config).to receive(:verify_multidigest_path).and_return multi_digest_path
      end

      context 'verification' do
        it 'logs the invocation' do
          process_status = instance_double('Process::Status', exitstatus: 0)
          allow(Open3).to receive(:capture3).with(multi_digest_path, "verify-multi-digest", "fake-file-path", "expected-sha").
            and_return(['foo', 'bar', process_status])
          expect(per_spec_logger).to receive(:info).with(/Verifying file shasum with command: "#{multi_digest_path} verify-multi-digest fake-file-path 'expected-sha'"/)
          expect(per_spec_logger).to receive(:info).with(/Shasum matched for file: 'fake-file-path' digest: 'expected-sha'/)
          subject.verify(file_path, 'expected-sha')
        end

        it 'does not raise an error when expected sha is correct' do
          process_status = instance_double('Process::Status', exitstatus: 0)
          allow(Open3).to receive(:capture3).with(multi_digest_path, "verify-multi-digest", "fake-file-path", "expected-sha").
            and_return(['foo', 'bar', process_status])

          expect { subject.verify(file_path, 'expected-sha') }.to_not raise_error
        end

        it 'does raise an error when expected sha is incorrect' do
          process_status = instance_double('Process::Status', exitstatus: 1)
          allow(Open3).to receive(:capture3).with(multi_digest_path, "verify-multi-digest", "fake-file-path", "expected-sha").
            and_return(['foo', 'bar', process_status])

          expect { subject.verify(file_path, 'expected-sha') }.to raise_error(ShaMismatchError, 'bar')
        end
      end

      context 'creation' do
        it 'creates sha1 digests from path' do
          process_status = instance_double('Process::Status', exitstatus: 0)
          allow(Open3).to receive(:capture3).with(multi_digest_path, 'create-multi-digest', 'sha1', 'fake-file-path').
            and_return(['fake-sha1', 'bar', process_status])

          result = subject.create([MultiDigest::SHA1], file_path)
          expect(result).to eq('fake-sha1')
        end

        it 'creates sha256 digests from path' do
          process_status = instance_double('Process::Status', exitstatus: 0)
          allow(Open3).to receive(:capture3).with(multi_digest_path, 'create-multi-digest', 'sha256', 'fake-file-path').
            and_return(['sha256:fake-sha2', 'bar', process_status])

          result = subject.create([MultiDigest::SHA256], file_path)
          expect(result).to eq('sha256:fake-sha2')
        end

        it 'creates multi-digests digests from path' do
          process_status = instance_double('Process::Status', exitstatus: 0)
          allow(Open3).to receive(:capture3).with(multi_digest_path, 'create-multi-digest', 'sha1,sha256', 'fake-file-path').
            and_return(['fake-sha1;sha256:fake-sha2', 'bar', process_status])

          result = subject.create([MultiDigest::SHA1,MultiDigest::SHA256], file_path)
          expect(result).to eq('fake-sha1;sha256:fake-sha2')
        end

        it 'raises an exception when the binary returns non-zero status' do
          process_status = instance_double('Process::Status', exitstatus: 1)
          allow(Open3).to receive(:capture3).with(multi_digest_path, 'create-multi-digest', 'sha1,sha256', 'fake-file-path').
            and_return(['fake-sha1;sha256:fake-sha2', 'bar', process_status])

          expect {
            subject.create([MultiDigest::SHA1,MultiDigest::SHA256], file_path)
          }.to raise_error(DigestCreationError, "bar")
        end

        it 'logs the invocation' do
          allow(Open3).to receive(:capture3).with(multi_digest_path, 'create-multi-digest', 'sha1,sha256', 'fake-file-path').
            and_return(['foo', 'bar', instance_double('Process::Status', exitstatus: 0)])
          expect(per_spec_logger).to receive(:info).with(/Creating digest with command: "#{multi_digest_path} create-multi-digest sha1,sha256 fake-file-path"/)
          expect(per_spec_logger).to receive(:info).with(/Digest 'foo' created for file: 'fake-file-path'/)
          subject.create([MultiDigest::SHA1,MultiDigest::SHA256], file_path)
        end
      end
    end
  end
end
