require 'spec_helper'
require 'tmpdir'

describe Bosh::PackageCompiler::Compiler do
  before :all do
    @base_dir = Dir.mktmpdir
    @blobstore_path = File.join(@base_dir, "blob_cache")
    FileUtils.mkdir(@blobstore_path)
  end

  let(:options) {
    {
      "blobstore_options" => {"blobstore_path" => @blobstore_path},
      "blobstore_provider" => "local",
      "base_dir" => @base_dir,
      "logfile" => "/tmp/spec.log",
      "manifest" => spec_asset(manifest),
      "release" => spec_asset(release_tar),
      "apply_spec" => File.join(@base_dir, "micro/apply_spec.yml"),
      :cpi => "vsphere",
      :job => "micro"
    }
  }

  let(:manifest) { "micro_bosh/micro_bosh.yml" }
  let(:release_tar) { "micro_bosh/micro_bosh.tgz" }

  after :all do
    FileUtils.rm_rf(@base_dir)
  end

  context "when" do
    let(:compiler) { Bosh::PackageCompiler::Compiler.new(options) }

    let(:test_agent) do
      agent = mock(:agent)
      agent.stub(:ping)
      agent.stub(:run_task).and_return(result)
      agent
    end

    let(:result) { {"result" => {"blobstore_id" => "blah", "sha1" => "blah"}} }

    before do
      Bosh::Agent::Client.should_receive(:create).and_return(test_agent)
    end

    it "should compile packages according to the manifest" do
      test_agent.stub(:run_task).with(:compile_package, kind_of(String), "sha1",
                                      /(ruby|nats|redis|libpq|postgres|blobstore|nginx|director|health_monitor)/,
                                      kind_of(String), kind_of(Hash)).and_return(result)
      compiler.compile.should include("director")
    end

    context "when job uses job collocation" do
      let(:manifest) { "micro_bosh_collo/micro_bosh_collo.yml" }
      let(:release_tar) { "micro_bosh_collo/micro_bosh_collo.tgz" }

      xit "should add collocated jobs in apply spec" do
        compiler.compile
        spec = Psych.load_file(compiler.apply_spec)

        spec_jobs = spec["job"]["templates"]
        spec_jobs.size.should eq(3)
        spec_jobs[0]["name"].should eq("nats")
        spec_jobs[1]["name"].should eq("redis")
        spec_jobs[2]["name"].should eq("postgres")
      end
    end

    context "when job does NOT use job collocation" do
      it "should put only this job in apply spec" do
        compiler.compile
        spec =Psych.load_file(compiler.apply_spec)
        spec["job"]["templates"].size.should eq(1)

        micro_job_spec = spec["job"]["templates"][0]
        micro_job_spec["name"].should eq("micro")
        micro_job_spec["version"].should eq("0.9-dev")
        micro_job_spec["sha1"].should eq("ab62ca83016af6ddd5b24d535e339ee193bc7168")
        micro_job_spec["blobstore_id"].should match(/[a-z\d-]/)
      end
    end

    it "should call agent start after applying custom properties" do
      test_agent.should_receive(:run_task).with(:stop)
      test_agent.should_receive(:run_task).with(:apply, kind_of(Hash))
      test_agent.should_receive(:run_task).with(:start)
      compiler.apply
    end
  end

  it "should compile packages for a specified job" do
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

  it "should respect spec properties if job properties are empty" do
    spec_properties = {
      "foo" => {"bar1" => "original"}
    }
    job_properties = {}

    @compiler = Bosh::PackageCompiler::Compiler.new(options)
    @compiler.add_default_properties(spec_properties, job_properties)
    spec_properties.should == spec_properties
  end

  it "should add default job properties to spec properties" do
    spec_properties = {
      "foo" => {"bar1" => "original"}
    }

    job_properties = {
      "foo.bar1" => {"default" => "notreplaced"},
      "foo.bar2" => {"default" => "added"},
      "bar.vtrue" => {"default" => true},
      "bar.vfalse" => {"default" => false}
    }

    @compiler = Bosh::PackageCompiler::Compiler.new(options)
    @compiler.add_default_properties(spec_properties, job_properties)
    spec_properties.should == {"foo" => {"bar1" => "original",
                                         "bar2" => "added"},
                               "bar" => {"vtrue" => true,
                                         "vfalse" => false}
                              }
  end

end
