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

  before do
    @logger = Logger.new("/dev/null")
  end

  describe 'download_remote_file' do
    it 'should download a remote file' do
      Net::HTTP.stub(:start).and_yield(http)
      http.should_receive(:request_get).and_yield(http_200)
      http_200.should_receive(:read_body)

      download_remote_file('resource', remote_file, local_file)
    end

    it 'should return a ResourceNotFound exception if remote server returns a NotFound error' do
      Net::HTTP.stub(:start).and_yield(http)
      http.should_receive(:request_get).and_yield(http_404)

      expect {
        download_remote_file('resource', remote_file, local_file)
      }.to raise_error(Bosh::Director::ResourceNotFound, "No resource found at `#{remote_file}'.")
    end

    it 'should return a ResourceError exception if remote server returns an error code' do
      Net::HTTP.stub(:start).and_yield(http)
      http.should_receive(:request_get).and_yield(http_500)

      expect {
        download_remote_file('resource', remote_file, local_file)
      }.to raise_error(Bosh::Director::ResourceError, 'Downloading remote resource failed. Check task debug log for details.')
    end

    it 'should return a ResourceError exception if there is a connection error' do
      Net::HTTP.stub(:start).and_raise(Timeout::Error)

      expect {
        download_remote_file('resource', remote_file, local_file)
      }.to raise_error(Bosh::Director::ResourceError, 'Downloading remote resource failed. Check task debug log for details.')
    end
  end


  describe 'http_proxy' do
    describe 'when no proxy defined in ENV' do
      it 'should return nil for http and https urls ' do
        with_env('http_proxy' => nil, 'https_proxy' => nil) {
          proxy_address, proxy_port = http_proxy(URI('https://host/path'))
          proxy_address.should be_nil
          proxy_port.should be_nil

          proxy_address, proxy_port = http_proxy(URI('http://host/path'))
          proxy_address.should be_nil
          proxy_port.should be_nil
        }
      end
    end
    describe 'when http_proxy and https_proxy defined in ENV' do
      it 'should return https proxy for https urls ' do
        with_env('http_proxy' => 'http://httpproxy:3128', 'https_proxy' => 'http://httpsproxy:3129') {
          proxy_address, proxy_port = http_proxy(URI('https://host/path'))
          proxy_address.should eq 'httpsproxy'
          proxy_port.should be 3129
        }
      end
      it 'should return http proxy for for http urls ' do
        with_env('http_proxy' => 'http://httpproxy:3128', 'https_proxy' => 'http://httpsproxy:3129') {
          proxy_address, proxy_port = http_proxy(URI('http://host/path'))
          proxy_address.should eq 'httpproxy'
          proxy_port.should be 3128
        }
      end
    end
  end

  def with_env(h)
    begin
      old = {}
      h.each_key { |k| old[k] = ENV[k] }
      h.each { |k, v| ENV[k] = v }
      yield
    ensure
      h.each_key { |k| ENV[k] = old[k] }
    end
  end

end