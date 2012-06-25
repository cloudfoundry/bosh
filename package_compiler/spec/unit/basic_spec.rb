require 'spec_helper'

describe Bosh::PackageCompiler::Compiler do
  before :all do
    @base_dir    = Dir.mktmpdir
    blobstore_path = File.join(@base_dir, "blob_cache")
    FileUtils.mkdir(blobstore_path)
    @options = {
          "blobstore_options" => { "blobstore_path" => blobstore_path },
          "blobstore_provider" => "local",
          "base_dir"  => @base_dir,
          "logfile" => File.join(@base_dir, "spec.log"),
          "manifest" => spec_asset("micro_bosh.yml"),
          "release" => spec_asset("micro_bosh.tgz"),
          "apply_spec" => File.join(@base_dir, "micro/apply_spec.yml"),
          :cpi => "vsphere",
          :job => "micro"
    }
  end

  after :all do
    FileUtils.rm_rf(@base_dir)
  end

  it "should compile packages according to the manifest" do
    @compiler = Bosh::PackageCompiler::Compiler.new(@options)
    test_agent = mock(:agent)
    test_agent.stub(:ping)
    result = {"result" => {"blobstore_id" => "blah", "sha1" => "blah"}}
    test_agent.stub(:run_task).with(:compile_package, kind_of(String), "sha1",
                                    /(ruby|nats|redis|libpq|postgres|blobstore|nginx|director|health_monitor)/,
                                    kind_of(String), kind_of(Hash)).and_return(result)
    Bosh::Agent::Client.should_receive(:create).and_return(test_agent)
    @compiler.compile.should include("director")
  end

  it "should call agent start after applying custom properties" do
    @compiler = Bosh::PackageCompiler::Compiler.new(@options)
    test_agent = mock(Object)
    test_agent.stub(:ping)
    result = {"result" => {"blobstore_id" => "blah", "sha1" => "blah"}}
    test_agent.stub(:run_task).and_return(result)
    Bosh::Agent::Client.should_receive(:create).and_return(test_agent)
    test_agent.should_receive(:run_task).with(:stop)
    test_agent.should_receive(:run_task).with(:apply, kind_of(Hash))
    test_agent.should_receive(:run_task).with(:start)
    @compiler.apply
  end

  it "should compile packages for a specified job" do
    options = @options.dup
    options[:job] = "micro_aws"
    @compiler = Bosh::PackageCompiler::Compiler.new(options)
    test_agent = mock(:agent)
    test_agent.stub(:ping)
    result = {"result" => {"blobstore_id" => "blah", "sha1" => "blah"}}
    test_agent.stub(:run_task).with(:compile_package, kind_of(String), "sha1",
                                    /(ruby|nats|redis|libpq|postgres|blobstore|nginx|director|health_monitor|aws_registry)/,
                                    kind_of(String), kind_of(Hash)).and_return(result)
    Bosh::Agent::Client.should_receive(:create).and_return(test_agent)
    @compiler.compile.should include("aws_registry")
  end

end
