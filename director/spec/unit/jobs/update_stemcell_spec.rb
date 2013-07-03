# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)
require 'net/http'

describe Bosh::Director::Jobs::UpdateStemcell do

  before(:each) do
    @cloud = mock("cloud")

    @tmpdir = Dir.mktmpdir("base_dir")

    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)
    Bosh::Director::Config.stub!(:base_dir).and_return(@tmpdir)

    stemcell_contents = create_stemcell("jeos", 5, {"ram" => "2gb"}, "image contents", "shawone")
    @stemcell_file = Tempfile.new("stemcell_contents")
    File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
  end

  after(:each) do
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@stemcell_file.path)
  end

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:update_stemcell)
    end
  end

  it "should upload a local stemcell" do
    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) { |f| f.read }
      contents.should eql("image contents")
      "stemcell-cid"
    end

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
    update_stemcell_job.perform

    stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
    stemcell.should_not be_nil
    stemcell.cid.should == "stemcell-cid"
    stemcell.sha1.should == "shawone"
  end

  it "should upload a remote stemcell" do
    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) { |f| f.read }
      contents.should eql("image contents")
      "stemcell-cid"
    end
    
    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path, {'remote' => true})
    update_stemcell_job.should_receive(:download_remote_stemcell)    
    update_stemcell_job.perform
    
    stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
    stemcell.should_not be_nil
    stemcell.cid.should == "stemcell-cid"
    stemcell.sha1.should == "shawone"
  end
  
  it "should cleanup the stemcell file" do
    @cloud.should_receive(:create_stemcell).with(anything(), {"ram" => "2gb"}).and_return do |image, _|
      contents = File.open(image) { |f| f.read }
      contents.should eql("image contents")
      "stemcell-cid"
    end

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
    update_stemcell_job.perform

    File.exist?(@stemcell_file.path).should be_false
  end

  it "should fail if the stemcell exists" do
    Bosh::Director::Models::Stemcell.make(:name => "jeos", :version => "5")

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

    lambda { update_stemcell_job.perform }.should raise_exception(Bosh::Director::StemcellAlreadyExists)
  end

  it "should fail if cannot extract stemcell" do
    result = Bosh::Exec::Result.new("cmd", "output", 1)
    Bosh::Exec.should_receive(:sh).and_return(result)

    update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

    expect {
      update_stemcell_job.perform
    }.to raise_exception(Bosh::Director::StemcellInvalidArchive)
  end
  
  describe 'download_remote_stemcell' do
    let(:http) { mock('http') }
    let(:http_200) { Net::HTTPSuccess.new('1.1', '200', 'OK') }
    let(:http_404) { Net::HTTPNotFound.new('1.1', 404, 'Not Found') }
    let(:http_500) { Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error') }
    let(:stemcell_uri) { 'http://example.com/stemcell.tgz' }

    it 'should download a remote stemcell' do
      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(stemcell_uri, {'remote' => true})
      SecureRandom.stub(:uuid).and_return('uuid')
      Net::HTTP.stub(:start).and_yield(http)
      http.should_receive(:request_get).and_yield(http_200)
      http_200.should_receive(:read_body)
      
      update_stemcell_job.download_remote_stemcell(@tmpdir)
    end
    
    it 'should return a StemcellNotFound exception if remote server returns a NotFound error' do
      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(stemcell_uri, {'remote' => true})
      Net::HTTP.stub(:start).and_yield(http)
      http.should_receive(:request_get).and_yield(http_404)
      
      expect {
        update_stemcell_job.download_remote_stemcell(@tmpdir)
      }.to raise_error(Bosh::Director::StemcellNotFound, "No stemcell found at `#{stemcell_uri}'.")
    end
    
    it 'should return a StemcellNotFound exception if remote server returns an error code' do
      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(stemcell_uri, {'remote' => true})
      Net::HTTP.stub(:start).and_yield(http)
      http.should_receive(:request_get).and_yield(http_500)
      
      expect {
        update_stemcell_job.download_remote_stemcell(@tmpdir)
      }.to raise_error(Bosh::Director::StemcellNotFound, 'Downloading remote stemcell failed. Check task debug log for details.')
    end
    
    it 'should return a ResourceError exception if stemcell URI is invalid' do
      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new('http://example.com?a|b', {'remote' => true})
      
      expect {
        update_stemcell_job.download_remote_stemcell(@tmpdir)
      }.to raise_error(Bosh::Director::ResourceError, 'Downloading remote stemcell failed. Check task debug log for details.')
    end
    
    it 'should return a ResourceError exception if there is a connection error' do
      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(stemcell_uri, {'remote' => true})
      Net::HTTP.stub(:start).and_raise(Timeout::Error) 
      
      expect {
        update_stemcell_job.download_remote_stemcell(@tmpdir)
      }.to raise_error(Bosh::Director::ResourceError, 'Downloading remote stemcell failed. Check task debug log for details.')
    end
  end
end
