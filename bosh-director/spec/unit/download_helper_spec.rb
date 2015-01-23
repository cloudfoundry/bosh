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
  let(:verify_mode) { OpenSSL::SSL::VERIFY_NONE }

  describe 'download_remote_file' do
    it 'should download a remote file' do
      expect(Net::HTTP).to receive(:start).with('example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http).once
      expect(http).to receive(:request_get).and_yield(http_200)
      expect(http_200).to receive(:read_body) do |&block|
        block.call("contents 1\n")
        block.call("contents 2\n")
      end

      download_remote_file('resource', remote_file, local_file)
      expect(File.read(local_file)).to eq("contents 1\ncontents 2\n")
    end

    context 'when the server redirects' do
      let(:http_302) { Net::HTTPFound.new('1.1', '302', 'Found').tap { |response| response.header['location'] = redirect_location } }
      let(:redirect_url) { 'http://redirector.example.com/redirect/to/file' }
      let(:redirect_location) { remote_file }

      it 'should follow the redirect' do
        expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http).once
        expect(Net::HTTP).to receive(:start).with('example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http).once
        expect(http).to receive(:request_get).with(URI.parse(redirect_url).request_uri).and_yield(http_302)
        expect(http).to receive(:request_get).with(URI.parse(remote_file).request_uri).and_yield(http_200)
        expect(http_200).to receive(:read_body)

        download_remote_file('resource', redirect_url, local_file)
      end

      context "when the location isn't fully qualified" do
        let(:redirect_location) { '/file.tgz' }

        it 'should evaluate the location relative to the server and follow the redirect' do
          expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http).twice
          expect(http).to receive(:request_get).with(URI.parse(redirect_url).request_uri).and_yield(http_302)
          expect(http).to receive(:request_get).with('/file.tgz').and_yield(http_200)
          expect(http_200).to receive(:read_body)

          download_remote_file('resource', redirect_url, local_file)
        end

        context 'when the location is a relative path' do
          let(:redirect_location) { 'file.tgz' }

          it 'should evaulate the location relative to the server and path and follow the redirect' do
            expect(Net::HTTP).to receive(:start).with('redirector.example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http).twice
            expect(http).to receive(:request_get).with(URI.parse(redirect_url).request_uri).and_yield(http_302)
            expect(http).to receive(:request_get).with('/redirect/to/file.tgz').and_yield(http_200)
            expect(http_200).to receive(:read_body)

            download_remote_file('resource', redirect_url, local_file)
          end
        end
      end

      context 'when the redirect has no location header' do
        let(:http_302) { Net::HTTPFound.new('1.1', '302', 'Found') }

        it 'should raise an error if no location is specified in a 302' do
          allow(Net::HTTP).to receive(:start).with('redirector.example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http)
          expect(http).to receive(:request_get).with(URI.parse(redirect_url).request_uri).and_yield(http_302)

          expect {
            download_remote_file('resource', redirect_url, local_file)
          }.to raise_error(Bosh::Director::ResourceError, "No location header for redirect found at `#{redirect_url}'.")
        end
      end

      it 'should raise an error if there are too many nested redirects' do
        allow(Net::HTTP).to receive(:start).and_yield(http)
        expect(http).to receive(:request_get).and_yield(http_302).exactly(10).times

        expect {
          download_remote_file('resource', redirect_url, local_file)
        }.to raise_error(Bosh::Director::ResourceError, "Too many redirects at `#{remote_file}'.")
      end
    end

    it 'should return a ResourceNotFound exception if remote server returns a NotFound error' do
      expect(Net::HTTP).to receive(:start).with('example.com', 80, use_ssl: false, verify_mode: verify_mode).and_yield(http)
      expect(http).to receive(:request_get).and_yield(http_404)

      expect {
        download_remote_file('resource', remote_file, local_file)
      }.to raise_error(Bosh::Director::ResourceNotFound, "No resource found at `#{remote_file}'.")
    end

    it 'should return a ResourceError exception if remote server returns an error code' do
      allow(Net::HTTP).to receive(:start).and_yield(http)
      expect(http).to receive(:request_get).and_yield(http_500)

      expect {
        download_remote_file('resource', remote_file, local_file)
      }.to raise_error(Bosh::Director::ResourceError, 'Downloading remote resource failed. Check task debug log for details.')
    end

    it 'should return a ResourceError exception if there is a connection error' do
      allow(Net::HTTP).to receive(:start).and_raise(Timeout::Error)

      expect {
        download_remote_file('resource', remote_file, local_file)
      }.to raise_error(Bosh::Director::ResourceError, 'Downloading remote resource failed. Check task debug log for details.')
    end
  end
end
