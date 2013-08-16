require 'spec_helper'

require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe DownloadAdapter do
    describe '#download' do
      include FakeFS::SpecHelpers

      let(:adapter) { DownloadAdapter.new }

      before(:each) do
        FileUtils.mkdir('/tmp')
      end

      let(:string_uri) { 'http://a.sample.uri/requesting/a/test.yml' }
      let(:uri) { URI(string_uri) }
      let(:write_path) { '/tmp/test.yml' }
      let(:content) { 'content' }

      context 'when the file exists' do
        before do
          stub_request(:get, string_uri).to_return(body: content)
        end

        it 'downloads the file to the specified directory' do
          adapter.download(uri, write_path)

          expect(File.read(write_path)).to eq(content)
        end

        context 'when passed a string instead of a uri' do
          it 'still works as expected' do
            adapter.download(string_uri, write_path)

            expect(File.read(write_path)).to eq(content)
          end
        end
      end

      context 'when the file does not exist' do
        before do
          stub_request(:get, string_uri).to_return(status: 404)
        end

        it 'raises an error if the file does not exist' do
          expect {
            adapter.download(uri, write_path)
          }.to raise_error(%r{remote file 'http://a.sample.uri/requesting/a/test.yml' not found})
        end
      end

    end
  end
end

