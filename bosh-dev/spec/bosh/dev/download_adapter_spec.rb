require 'spec_helper'
require 'logger'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe DownloadAdapter do
    describe '#download' do
      include FakeFS::SpecHelpers

      subject { described_class.new(logger) }
      let(:logger) { Logger.new('/dev/null') }

      before(:each) { FileUtils.mkdir('/tmp') }

      let(:string_uri) { 'http://a.sample.uri/requesting/a/test.yml' }
      let(:uri) { URI(string_uri) }
      let(:write_path) { '/tmp/test.yml' }
      let(:content) { 'content' }

      context 'when the remote file exists' do
        before { stub_request(:get, string_uri).to_return(body: content) }

        it 'downloads the file to the specified directory' do
          subject.download(uri, write_path)
          expect(File.read(write_path)).to eq(content)
        end

        context 'when write path is an absolute path' do
          it 'returns the full path of the downloaded file' do
            actual = subject.download(uri, write_path)
            expect(actual).to eq(write_path)
          end
        end

        context 'when write path is a relative path' do
          it 'returns the full path of the downloaded file' do
            actual = subject.download(uri, 'relative-write-path')
            expect(actual).to eq(File.join(Dir.pwd, 'relative-write-path'))
          end
        end

        context 'when passed a string instead of a uri' do
          it 'still works as expected' do
            subject.download(string_uri, write_path)
            expect(File.read(write_path)).to eq(content)
          end
        end
      end

      context 'when the remote file does not exist' do
        before { stub_request(:get, string_uri).to_return(status: 404) }

        it 'raises an error if the file does not exist' do
          expect {
            subject.download(uri, write_path)
          }.to raise_error(%r{remote file 'http://a.sample.uri/requesting/a/test.yml' not found})
        end
      end

      context 'when a proxy is available' do
        before { stub_const('ENV', 'http_proxy' => 'http://proxy.example.com:1234') }

        it 'uses the proxy' do
          net_http_mock = class_double('Net::HTTP').as_stubbed_const
          net_http_mock.should_receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234)
          subject.download(uri, write_path)
        end
      end
    end
  end
end
