# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::UpdateRelease do

  before(:each) do
    @blobstore = mock("blobstore_client")
    @logger = Logger.new(StringIO.new)
    @release_dir = Dir.mktmpdir("release_dir")

    Bosh::Director::Config.stub!(:blobstore).and_return(@blobstore)
    Bosh::Director::Config.stub!(:logger).and_return(@logger)
  end

  describe "create_package" do

    before(:each) do
      @release = Bosh::Director::Models::Release.make

      @job = Bosh::Director::Jobs::UpdateRelease.new(@release_dir)
      @job.release = @release
    end

    after(:each) do
      FileUtils.rm_rf(@release_dir)
    end

    it "should create simple packages" do
      FileUtils.mkdir_p(File.join(@release_dir, "packages"))
      package_path = File.join(@release_dir, "packages", "test_package.tgz")

      File.open(package_path, "w") do |f|
        f.write(create_package({"test" => "test contents"}))
      end

      @blobstore.should_receive(:create).with(
        have_a_path_of(package_path)).and_return("blob_id")

      @job.create_package(
        {
          "name" => "test_package", "version" => "1.0", "sha1" => "some-sha",
          "dependencies" => %w(foo_package bar_package)
        }
      )

      package = Bosh::Director::Models::Package[:name => "test_package",
                                                :version => "1.0"]
      package.should_not be_nil
      package.name.should == "test_package"
      package.version.should == "1.0"
      package.release.should == @release
      package.sha1.should == "some-sha"
      package.blobstore_id.should == "blob_id"
    end

  end

  describe "resolve_package_dependencies" do

    before(:each) do
      @job = Bosh::Director::Jobs::UpdateRelease.new(@release_dir)
    end

    it "should normalize nil dependencies" do
      packages = [{"name" => "A"}, {"name" => "B", "dependencies" => ["A"]}]
      @job.resolve_package_dependencies(packages)
      packages.should eql([
                            {"dependencies" => [], "name" => "A"},
                            {"dependencies" => ["A"], "name" => "B"}
                          ])
    end

    it "should not allow cycles" do
      packages = [
        {"name" => "A", "dependencies" => ["B"]},
        {"name" => "B", "dependencies" => ["A"]}
      ]

      lambda {
        @job.resolve_package_dependencies(packages)
      }.should raise_exception
    end

    it "should resolve nested dependencies" do
      packages = [
        {"name" => "A", "dependencies" => ["B"]},
        {"name" => "B", "dependencies" => ["C"]}, {"name" => "C"}
      ]

      @job.resolve_package_dependencies(packages)
      packages.should eql([
                            {"dependencies" => ["B", "C"], "name" => "A"},
                            {"dependencies" => ["C"], "name" => "B"},
                            {"dependencies" => [], "name" => "C"}
                          ])
    end

  end


  describe "create jobs" do

    before :each do
      @release = Bosh::Director::Models::Release.make
      @tarball = File.join(@release_dir, "jobs", "foo.tgz")
      @job_bits = create_job(
        "foo", "monit",
        {"foo" => {"destination" => "foo", "contents" => "bar"}}
      )

      @job_attrs = {
        "name" => "foo",
        "version" => "1",
        "sha1" => "deadbeef"
      }

      FileUtils.mkdir_p(File.dirname(@tarball))

      @job = Bosh::Director::Jobs::UpdateRelease.new(@release_dir)
      @job.release = @release
    end

    it "should create a proper template and upload job bits to blobstore" do
      File.open(@tarball, "w") { |f| f.write(@job_bits) }

      @blobstore.should_receive(:create).and_return do |f|
        f.rewind
        Digest::SHA1.hexdigest(f.read).should ==
          Digest::SHA1.hexdigest(@job_bits)

        Digest::SHA1.hexdigest(f.read)
      end

      Bosh::Director::Models::Template.count.should == 0
      @job.create_job(@job_attrs)

      template = Bosh::Director::Models::Template.first
      template.name.should == "foo"
      template.version.should == "1"
      template.release.should == @release
      template.sha1.should == "deadbeef"
    end

    it "whines on invalid archive" do
      File.open(@tarball, "w") { |f| f.write("deadcafe") }

      lambda {
        @job.create_job(@job_attrs)
      }.should raise_error(Bosh::Director::JobInvalidArchive)
    end

    it "whines on missing manifest" do
      @job_no_mf = create_job("foo", "monit",
                              {"foo" => {
                                "destination" => "foo",
                                "contents" => "bar"}},
                              :skip_manifest => true)
      File.open(@tarball, "w") { |f| f.write(@job_no_mf) }

      lambda {
        @job.create_job(@job_attrs)
      }.should raise_error(Bosh::Director::JobMissingManifest)
    end

    it "whines on missing monit file" do
      @job_no_monit = create_job("foo", "monit",
                                 {"foo" => {
                                   "destination" => "foo",
                                   "contents" => "bar"}},
                                 :skip_monit => true)
      File.open(@tarball, "w") { |f| f.write(@job_no_monit) }

      lambda {
        @job.create_job(@job_attrs)
      }.should raise_error(Bosh::Director::JobMissingMonit)
    end

    it "does not whine when it has a foo.monit file" do
      @job_no_monit = create_job("foo", "monit",
                                 {"foo" => {
                                   "destination" => "foo",
                                   "contents" => "bar"}},
                                 :monit_file => "foo.monit")
      File.open(@tarball, "w") { |f| f.write(@job_no_monit) }

      lambda {
        @job.create_job(@job_attrs)
      }.should_not raise_error(Bosh::Director::JobMissingMonit)
    end

    it "whines on missing template" do
      @job_no_monit = create_job("foo", "monit",
                                 {"foo" => {
                                   "destination" => "foo",
                                   "contents" => "bar"}},
                                 :skip_templates => ["foo"])
      File.open(@tarball, "w") { |f| f.write(@job_no_monit) }

      lambda {
        @job.create_job(@job_attrs)
      }.should raise_error(Bosh::Director::JobMissingTemplateFile)
    end
  end

end
