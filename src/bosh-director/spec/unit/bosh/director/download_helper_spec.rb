# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'

describe Bosh::Director::DownloadHelper do
  include Bosh::Director::DownloadHelper

  let(:http) { double('http') }
  let(:http_200) { Net::HTTPSuccess.new('1.1', '200', 'OK') }
  let(:http_404) { Net::HTTPNotFound.new('1.1', 404, 'Not Found') }
  let(:http_500) { Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error') }
  let(:remote_file) { 'http://example.com/file.tgz' }
  let(:local_file) { File.join(Dir.tmpdir, 'resource.tgz') }

  describe 'download_remote_file' do
    it 'should download a remote file' do
      expect(Net::HTTP).to receive(:start).with('example.com', 80, :ENV, use_ssl: false).and_yield(http).once
      expect(http).to receive(:request).and_yield(http_200)
      expect(http_200).to receive(:read_body) do |&block|
        block.call("contents 1\n")
        block.call("contents 2\n")
      end

      download_remote_file('resource', remote_file, local_file)
      expect(File.read(local_file)).to eq("contents 1\ncontents 2\n")
    end

    context 'when the remote file uri uses https' do
      let(:remote_file) { 'https://example.com/file.tgz' }

      it 'should use ssl' do
        expect(Net::HTTP).to receive(:start).with('example.com', 443, :ENV, use_ssl: true).and_yield(http).once

        expect(http).to receive(:request).and_yield(http_200)
        expect(http_200).to receive(:read_body) do |&block|
          block.call("contents 1\n")
          block.call("contents 2\n")
        end

        download_remote_file('resource', remote_file, local_file)
        expect(File.read(local_file)).to eq("contents 1\ncontents 2\n")
      end
    end

    context 'when using credentials' do
      let(:remote_file) { 'http://user:password@example.com/file.tgz' }

      it 'sets basic auth for the call' do
        expect(Net::HTTP).to receive(:start).with('example.com', 80, :ENV, use_ssl: false).and_yield(http).once
        expect(http).to receive(:request).and_yield(http_200)
        expect(http_200).to receive(:read_body)
        expect_any_instance_of(Net::HTTP::Get).to receive(:basic_auth).with('user', 'password')

        download_remote_file('resource', remote_file, local_file)
      end
    end

    context 'when the server redirects' do
      let(:http_302) { Net::HTTPFound.new('1.1', '302', 'Found').tap { |response| response.header['location'] = redirect_location } }
      let(:http_301) { Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently').tap { |response| response.header['location'] = redirect_location } }
      let(:redirect_url) { 'http://redirector.example.com/redirect/to/file' }
      let(:redirect_location) { remote_file }
      let(:redirect_request) { double }
      let(:request) { double }

      before(:each) do
        allow(Net::HTTP::Get).to receive(:new).with(URI.parse(redirect_url)).and_return(redirect_request).once
        allow(Net::HTTP::Get).to receive(:new).with(URI.parse(remote_file)).and_return(request)
      end

      it 'should follow the 302 redirect' do
        expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, :ENV, use_ssl: false).and_yield(http).once
        expect(Net::HTTP).to receive(:start).with('example.com', 80, :ENV, use_ssl: false).and_yield(http).once
        expect(http).to receive(:request).with(redirect_request).and_yield(http_302)
        expect(http).to receive(:request).with(request).and_yield(http_200)
        expect(http_200).to receive(:read_body)

        download_remote_file('resource', redirect_url, local_file)
      end

      it 'should follow the 301 redirect' do
        expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, :ENV, use_ssl: false).and_yield(http).once
        expect(Net::HTTP).to receive(:start).with('example.com', 80, :ENV, use_ssl: false).and_yield(http).once
        expect(http).to receive(:request).with(redirect_request).and_yield(http_301)
        expect(http).to receive(:request).with(request).and_yield(http_200)
        expect(http_200).to receive(:read_body)

        download_remote_file('resource', redirect_url, local_file)
      end

      context "when the location isn't fully qualified" do
        let(:redirect_location) { '/file.tgz' }
        let(:remote_file) { 'http://redirector.example.com/file.tgz' }

        it 'should evaluate the location relative to the server and follow the redirect' do
          expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, :ENV, use_ssl: false).and_yield(http).twice
          expect(http).to receive(:request).with(redirect_request).and_yield(http_302)
          expect(http).to receive(:request).with(request).and_yield(http_200)
          expect(http_200).to receive(:read_body)

          download_remote_file('resource', redirect_url, local_file)
        end

        context 'when the location is a relative path' do
          let(:redirect_location) { 'file.tgz' }
          let(:remote_file) { 'http://redirector.example.com/redirect/to/file.tgz' }

          it 'should evaulate the location relative to the server and path and follow the redirect' do
            expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, :ENV, use_ssl: false).and_yield(http).twice
            expect(http).to receive(:request).with(redirect_request).and_yield(http_302)
            expect(http).to receive(:request).with(request).and_yield(http_200)
            expect(http_200).to receive(:read_body)

            download_remote_file('resource', redirect_url, local_file)
          end
        end
      end

      context 'when the redirect has no location header' do
        let(:http_302) { Net::HTTPFound.new('1.1', '302', 'Found') }
        let(:redirect_url) { 'http://user:password@redirector.example.com/redirect/to/file' }
        let(:redirect_url_redacted) { 'http://<redacted>:<redacted>@redirector.example.com/redirect/to/file' }
        let(:redirect_location) { 'http://user:password@example.com/file.tgz' }

        it 'should raise an error if no location is specified in a 302' do
          allow(Net::HTTP::Get).to receive(:new).with(URI.parse(redirect_url)).and_return(redirect_request)
          allow(Net::HTTP).to receive(:start).with('redirector.example.com', 80, :ENV, use_ssl: false).and_yield(http)
          expect(redirect_request).to receive(:basic_auth).with('user', 'password')
          expect(http).to receive(:request).with(redirect_request).and_yield(http_302)

          expect do
            download_remote_file('resource', redirect_url, local_file)
          end.to raise_error(
            Bosh::Director::ResourceError,
            "No location header for redirect found at '#{redirect_url_redacted}'.",
          )
        end
      end

      it 'should raise an error if there are too many nested redirects' do
        allow(Net::HTTP).to receive(:start).and_yield(http)
        expect(http).to receive(:request).and_yield(http_302).exactly(10).times

        expect do
          download_remote_file('resource', redirect_url, local_file)
        end.to raise_error(Bosh::Director::ResourceError, "Too many redirects at '#{remote_file}'.")
      end
    end

    context 'when remote server returns an error' do
      let(:remote_file) { 'http://user:password@example.com/file.tgz' }
      let(:remote_file_redacted) { 'http://<redacted>:<redacted>@example.com/file.tgz' }

      before do
        # DownloadHelper expects @logger to exist
        @logger = double
      end

      it 'should return a ResourceNotFound exception and redact basic auth' do
        expect(Net::HTTP).to receive(:start).with('example.com', 80, :ENV, use_ssl: false).and_yield(http)
        expect(http).to receive(:request).and_yield(http_404)

        expect(@logger).to receive(:info).with(/#{remote_file_redacted}/)
        expect(@logger).to receive(:error).with(/#{remote_file_redacted}/)

        expect do
          download_remote_file('resource', remote_file, local_file)
        end.to raise_error(Bosh::Director::ResourceNotFound, "No resource found at '#{remote_file_redacted}'.")
      end

      it 'should return a ResourceError exception if remote server returns an error code' do
        allow(Net::HTTP).to receive(:start).and_yield(http)
        expect(http).to receive(:request).and_yield(http_500)

        expect(@logger).to receive(:info).with(/#{remote_file_redacted}/)
        expect(@logger).to receive(:error).with(/#{remote_file_redacted}/)

        expect do
          download_remote_file('resource', remote_file, local_file)
        end.to raise_error(Bosh::Director::ResourceError, 'Downloading remote resource failed. Check task debug log for details.')
      end

      it 'should return a ResourceError exception if there is a connection error' do
        allow(Net::HTTP).to receive(:start).and_raise(Timeout::Error)

        expect(@logger).to receive(:info).with(/#{remote_file_redacted}/)
        expect(@logger).to receive(:error).with(/#{remote_file_redacted}/)

        expect do
          download_remote_file('resource', remote_file, local_file)
        end.to raise_error(Bosh::Director::ResourceError, 'Downloading remote resource failed. Check task debug log for details.')
      end
    end
  end
end
