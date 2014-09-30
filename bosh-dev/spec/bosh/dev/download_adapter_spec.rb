require 'spec_helper'
require 'logger'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe DownloadAdapter do
    describe '#download' do
      include FakeFS::SpecHelpers

      subject { described_class.new(logger) }
      let(:logger) { Logger.new(StringIO.new) }

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

        it 'creates the parent directory for destination' do
          expect(FileUtils).to receive(:mkdir_p).with('/tmp')
          subject.download(uri, write_path)
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
          expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234, nil, nil)
          subject.download(uri, write_path)
        end
      end

      context 'when a proxy is available and contains the user and password' do
        before { stub_const('ENV', 'http_proxy' => 'http://user:password@proxy.example.com:1234') }

        it 'uses the proxy' do
          net_http_mock = class_double('Net::HTTP').as_stubbed_const
          expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234, 'user', 'password')
          subject.download(uri, write_path)
        end
      end

      context 'when some uris are specified to bypass the proxy' do
        before { stub_const('ENV', 'http_proxy' => 'http://proxy.example.com:1234', 'no_proxy' => bypass_proxy_uris)}

        context 'when the URL does not match the bypass_proxy_uris list' do
          let(:bypass_proxy_uris) { 'does.not.match,at.all' }

          it 'uses the proxy' do
            net_http_mock = class_double('Net::HTTP').as_stubbed_const
            expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234, nil, nil)
            subject.download(uri, write_path)
          end
        end

        context 'when the URL matches the bypass_proxy_uris list' do
          let(:bypass_proxy_uris) { 'some.example,sample.uri,another.example' }

          it 'does not use the proxy' do
            net_http_mock = class_double('Net::HTTP').as_stubbed_const
            expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, nil, nil, nil, nil)
            subject.download(uri, write_path)
          end
        end

        context 'when the URL matches the bypass_proxy_uris list, even if specified with leading .' do
          let(:bypass_proxy_uris) { 'some.domain,.sample.uri' }

          it 'does not use the proxy' do
            net_http_mock = class_double('Net::HTTP').as_stubbed_const
            expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, nil, nil, nil, nil)
            subject.download(uri, write_path)
          end
        end
      end
    end
  end
end
