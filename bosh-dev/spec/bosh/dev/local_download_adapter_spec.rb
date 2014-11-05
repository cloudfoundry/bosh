require 'spec_helper'
require 'bosh/dev/local_download_adapter'

describe Bosh::Dev::LocalDownloadAdapter do
  include FakeFS::SpecHelpers

  subject { described_class.new(logger) }

  describe '#download' do
    before { FileUtils.mkdir('/tmp') }

    context 'when the source file exists' do
      before { File.open('/tmp/source', 'w') { |f| f.write('content') } }

      it 'copies the file to the specified directory' do
        subject.download('/tmp/source', '/tmp/destination')
        expect(File.read('/tmp/destination')).to eq('content')
      end

      context 'when write path is an absolute path' do
        it 'returns the full path of the destination file' do
          actual = subject.download('/tmp/source', '/tmp/destination')
          expect(actual).to eq('/tmp/destination')
        end
      end

      context 'when write path is a relative path' do
        it 'returns the full path of the destination file' do
          actual = subject.download('/tmp/source', 'relative-destination')
          expect(actual).to eq(File.join(Dir.pwd, 'relative-destination'))
        end
      end
    end

    context 'when the source file does not exist' do
      it 'raises an error if the file does not exist' do
        expect {
          subject.download('/tmp/source-that-does-not-exist', '/tmp/destination')
        }.to raise_error(%r{No such file or directory - /tmp/source-that-does-not-exist})
      end
    end
  end
end
