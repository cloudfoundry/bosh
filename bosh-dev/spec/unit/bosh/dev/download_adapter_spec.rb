require 'spec_helper'
require 'bosh/dev/download_adapter'

module Bosh::Dev
  describe DownloadAdapter do
    describe '#download' do
      include FakeFS::SpecHelpers

      subject { described_class.new(logger) }

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

        context 'when a download times out' do
          let(:partial_downloads) { true }
          let(:bytes_to_return) { 4 }
          let(:fail_on_requests) { [0] }
          let(:send_entire_file_on_requests) { [] }
          before do
            request_count = -1

            allow_any_instance_of(Net::HTTP).to receive(:request_get) do |http, uri, headers, &block|
              request_count += 1
              response = Net::HTTPPartialContent.new(nil, "206", "ok")
              offset = 0
              if partial_downloads && headers['Range'] && headers['Range'] =~ /^bytes=(\d+)-$/
                offset = $1.to_i
                content_range = "bytes #{offset}-#{offset+bytes_to_return-1}/#{content.length}"
                response['Content-Range'] = content_range
              end

              allow(response).to receive(:read_body) do |&read_body_block|
                if send_entire_file_on_requests.include?(request_count)
                  read_body_block.call(content)
                else
                  read_body_block.call(content[offset..(offset+bytes_to_return-1)])
                  raise Timeout::Error if fail_on_requests.include?(request_count)
                end
              end

              block.call(response)
            end
          end

          it 'resumes the download' do
            subject.download(string_uri, write_path)
            expect(File.read(write_path)).to eq("content")
          end

          context 'if a server does not honor the range header' do
            let(:partial_downloads) { false }
            let(:send_entire_file_on_requests) { [1] }

            it 'resumes the download but overwrites the bits that were already downloaded' do
              subject.download(string_uri, write_path)
              expect(File.read(write_path)).to eq("content")
            end
          end

          context 'when the third try times out' do
            let(:bytes_to_return) { 1 }
            let(:fail_on_requests) { [0, 1, 2, 3] }

            it 'bails' do
              expect { subject.download(string_uri, write_path) }.to raise_exception(Timeout::Error)
              expect(File.exist?(write_path)).to eq(false)
            end
          end
        end
      end

      context 'when some error occurs' do
        before { stub_request(:get, string_uri).to_return(status: 500) }

        it 'raises an error' do
          expect {
            subject.download(uri, write_path)
          }.to raise_error(%r{error 500 while downloading 'http://a.sample.uri/requesting/a/test.yml'})
        end
      end

      context 'when a proxy is available' do
        before { stub_const('ENV', 'http_proxy' => 'http://proxy.example.com:1234') }

        it 'uses the proxy' do
          net_http_mock = class_double('Net::HTTP').as_stubbed_const
          mock_http = double(:http, :finish => nil, 'read_timeout=' => nil, :request_get => nil)
          expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234, nil, nil) { mock_http }
          subject.download(uri, write_path)
        end
      end

      context 'when a proxy is available and contains the user and password' do
        before { stub_const('ENV', 'http_proxy' => 'http://user:password@proxy.example.com:1234') }

        it 'uses the proxy' do
          net_http_mock = class_double('Net::HTTP').as_stubbed_const
          mock_http = double(:http, :finish => nil, 'read_timeout=' => nil, :request_get => nil)
          expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234, 'user', 'password') { mock_http }
          subject.download(uri, write_path)
        end
      end

      context 'when some uris are specified to bypass the proxy' do
        before { stub_const('ENV', 'http_proxy' => 'http://proxy.example.com:1234', 'no_proxy' => bypass_proxy_uris)}

        context 'when the URL does not match the bypass_proxy_uris list' do
          let(:bypass_proxy_uris) { 'does.not.match,at.all' }

          it 'uses the proxy' do
            net_http_mock = class_double('Net::HTTP').as_stubbed_const
            mock_http = double(:http, :finish => nil, 'read_timeout=' => nil, :request_get => nil)
            expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, 'proxy.example.com', 1234, nil, nil) { mock_http }
            subject.download(uri, write_path)
          end
        end

        context 'when the URL matches the bypass_proxy_uris list' do
          let(:bypass_proxy_uris) { 'some.example,sample.uri,another.example' }

          it 'does not use the proxy' do
            net_http_mock = class_double('Net::HTTP').as_stubbed_const
            mock_http = double(:http, :finish => nil, 'read_timeout=' => nil, :request_get => nil)
            expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, nil, nil, nil, nil) { mock_http }
            subject.download(uri, write_path)
          end
        end

        context 'when the URL matches the bypass_proxy_uris list, even if specified with leading .' do
          let(:bypass_proxy_uris) { 'some.domain,.sample.uri' }

          it 'does not use the proxy' do
            net_http_mock = class_double('Net::HTTP').as_stubbed_const
            mock_http = double(:http, :finish => nil, 'read_timeout=' => nil, :request_get => nil)
            expect(net_http_mock).to receive(:start).with('a.sample.uri', 80, nil, nil, nil, nil) { mock_http }
            subject.download(uri, write_path)
          end
        end
      end
    end
  end
end
