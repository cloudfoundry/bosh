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
end
