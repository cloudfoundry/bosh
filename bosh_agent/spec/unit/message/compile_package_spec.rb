require "spec_helper"

describe Bosh::Agent::Message::CompilePackage do
  before do
    Bosh::Agent::Config.blobstore_provider = 'simple'
    Bosh::Agent::Config.blobstore_options = { 'fake-key' => 'fake-value' }
    @httpclient = double("httpclient")
    HTTPClient.stub(:new).and_return(@httpclient)

    Bosh::Agent::Config.agent_id = Time.now.to_i

    args = "some_blobstore_id", "some_sha1", "some_name", 1
    @handler = Bosh::Agent::Message::CompilePackage.new(args)

    @handler.compile_base = File.dirname(__FILE__) + "/../../tmp/data/compile"
    @handler.install_base = File.dirname(__FILE__) + "/../../tmp/data/packages"
    @handler.stub(:disk_used).and_return(5)
    @handler.stub(:disk_total).and_return(10)
  end

  it "should have a blobstore client" do
    blobstore_client = double('fake-blobstore-client')
    Bosh::Blobstore::Client
      .should_receive(:safe_create)
      .with('simple', { 'fake-key' => 'fake-value' })
      .and_return(blobstore_client)
    handler = Bosh::Agent::Message::CompilePackage.new(nil)
    expect(handler.blobstore_client).to eq(blobstore_client)
  end

  it "should unpack a package" do
    dummy_compile_data

    package_file = File.join(@handler.compile_base, "tmp",
                             @handler.blobstore_id)
    File.exist?(package_file).should be(false)
    @handler.get_source_package
    File.exist?(package_file).should be(true)

    compile_dir = File.join(@handler.compile_base, @handler.package_name)
    File.directory?(compile_dir).should be(false)
    @handler.unpack_source_package
    File.directory?(compile_dir).should be(true)
    File.exist?(File.join(compile_dir, "packaging")).should be(true)
  end

  it "should compile a package" do
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package

    @handler.compile
    dummy_file = File.join(@handler.install_base, @handler.package_name,
                           @handler.package_version.to_s, "dummy.txt")
    File.exist?(dummy_file).should be(true)
  end

  it "should fail packaging script returns a non-zero exit code" do
    dummy_failing_compile_data

    @handler.get_source_package
    @handler.unpack_source_package

    expect {
      @handler.compile
    }.to raise_error(Bosh::Agent::MessageHandlerError,
                     /Compile Package Failure/)
  end

  it "should pack a compiled package" do
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package
    @handler.compile
    @handler.pack
  end

  it "should upload compiled package" do
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package
    @handler.compile
    @handler.pack

    # This should probably just be stubbed
    sha1 = Digest::SHA1.file(@handler.compiled_package).hexdigest
    File.open(@handler.compiled_package) do |f|
      stub_blobstore_id = "bfa8e2e1-d386-4df7-ad5e-fd21f49333d6"
      compile_log_id = "bfa8e2e1-d386-4df7-ad5e-fd21f49333d7"

      @handler.blobstore_client.stub(:create).
          and_return(stub_blobstore_id, compile_log_id)
      result = @handler.upload
      result.delete("compile_log")
      result.should == { "sha1" => sha1, "blobstore_id" => stub_blobstore_id,
                         "compile_log_id" => compile_log_id}
    end
  end

  it "should correctly calculate disk percentage used" do
    @handler.stub(:disk_used).and_return(6)
    @handler.stub(:disk_total).and_return(10)
    @handler.pct_disk_used("./").should == 60
  end

  it "should throw error when disk percentage >= 90" do
    @handler.stub(:pct_disk_used).and_return(90)
    dummy_compile_data

    @handler.get_source_package
    @handler.unpack_source_package
    expect {
      @handler.compile
    }.to raise_error(Bosh::Agent::MessageHandlerError)
  end

  it "should clear the log file every time create_logger is called" do
    Dir.mktmpdir do |dir|
      logger = @handler.clear_log_file("#{dir}/logger")
      logger.info("test log data")
      logger.close
      File.read("#{dir}/logger")["test log data"].should_not be_nil
      logger = @handler.clear_log_file("#{dir}/logger")
      logger.close
      File.read("#{dir}/logger")["test log data"].should be_nil
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
    response = double("response")
    response.stub(:status).and_return(200)
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(data).
        and_return(response)
  end

end
