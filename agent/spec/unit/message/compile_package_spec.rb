require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Agent::Message::CompilePackage do

  before(:each) do
    Bosh::Agent::Config.blobstore_provider = "simple"
    Bosh::Agent::Config.blobstore_options = {}
    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)

    Bosh::Agent::Config.agent_id = Time.now.to_i

    args = "some_blobstore_id", "some_sha1", "some_name", 1
    @handler = Bosh::Agent::Message::CompilePackage.new(args)

    @handler.compile_base = File.dirname(__FILE__) + '/../../tmp/data/compile'
    @handler.install_base = File.dirname(__FILE__) + '/../../tmp/data/packages'
  end

  it 'should have a blobstore client' do
    handler = Bosh::Agent::Message::CompilePackage.new(nil)
    handler.blobstore_client.should be_an_instance_of Bosh::Blobstore::SimpleBlobstoreClient
  end


  # TODO: this is essentially re-testing the blobstore client, but I didn't know the API well enough
  it 'should unpack a package' do
    dummy_compile_data

    package_file = File.join(@handler.compile_base, 'tmp', @handler.blobstore_id)
    File.exist?(package_file).should be_false
    @handler.get_source_package
    File.exist?(package_file).should be_true

    compile_dir = File.join(@handler.compile_base, @handler.package_name)
    File.directory?(compile_dir).should be_false
    @handler.unpack_source_package
    File.directory?(compile_dir).should be_true
    File.exist?(File.join(compile_dir, 'packaging')).should be_true
  end

  it 'should compile a package' do
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package
    @handler.compile

    dummy_file = File.join(@handler.install_base, @handler.package_name, @handler.package_version.to_s, 'dummy.txt')
    File.exist?(dummy_file).should be_true
  end

  it 'should fail packaing script returns a non-zero exit code' do
    dummy_failing_compile_data

    @handler.get_source_package
    @handler.unpack_source_package

    lambda {
      @handler.compile
    }.should raise_error(Bosh::Agent::MessageHandlerError, /Compile Package Failure/)
  end

  it 'should pack a compiled package' do
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package
    @handler.compile
    @handler.pack
  end

  it 'should upload compiled package' do
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package
    @handler.compile
    @handler.pack

    # This should probably just be stubbed
    sha1 = Digest::SHA1.hexdigest(File.read(@handler.compiled_package))
    File.open(@handler.compiled_package) do |f|
      stub_blobstore_id = "bfa8e2e1-d386-4df7-ad5e-fd21f49333d6"

      @handler.blobstore_client.stub(:create).with(instance_of(File)).and_return(stub_blobstore_id)
      result = @handler.upload
      result.delete('compile_log')
      result.should == { "sha1" => sha1, "blobstore_id" => stub_blobstore_id}
    end
  end

  def dummy_compile_data
    dummy_compile_setup(dummy_package_data)
  end

  def dummy_failing_compile_data
    dummy_compile_setup(failing_package_data)
  end

  def dummy_compile_setup(data)
    FileUtils.rm_rf @handler.compile_base
    response = mock("response")
    response.stub!(:status).and_return(200)
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(data).and_return(response)
  end

end
