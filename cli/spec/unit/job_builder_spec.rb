require "spec_helper"
require "fileutils"

describe Bosh::Cli::JobBuilder do

  before(:each) do
    @release_dir = Dir.mktmpdir
  end

  def new_builder(name, packages = [], configs = { }, built_packages = [])
    spec = {
      "name"          => name,
      "packages"      => packages,
      "configuration" => configs
    }
    add_spec(name)
    Bosh::Cli::JobBuilder.new(spec, @release_dir, built_packages)
  end

  def add_file(job_name, file)
    job_dir = File.join(@release_dir, "jobs", job_name)
    FileUtils.mkdir_p(job_dir)
    FileUtils.touch(File.join(job_dir, file))    
  end

  def add_spec(job_name)
    add_file(job_name, "spec")
  end  

  def add_monit(job_name)
    add_file(job_name, "monit")
  end

  def add_configs(job_name, *files)
    job_config_path = File.join(@release_dir, "jobs", job_name, "config")
    FileUtils.mkdir_p(job_config_path)

    files.each do |file|
      add_file(job_name, "config/#{file}")
    end
  end

  it "creates a new builder" do
    builder = new_builder("foo", ["foo", "bar", "baz"], ["a.conf", "b.yml"])
    builder.packages.should    == ["foo", "bar", "baz"]
    builder.configs.should     == ["a.conf", "b.yml"]
    builder.release_dir.should == @release_dir
  end

  it "can read config file names from hash" do
    builder = new_builder("foo", ["foo", "bar", "baz"], {"a.conf" => 1, "b.yml" => 2})
    builder.configs.should =~ ["a.conf", "b.yml"]
  end

  it "whines if name is blank" do
    lambda {
      new_builder("")
    }.should raise_error(Bosh::Cli::InvalidJob, "Job name is missing")
  end

  it "whines on funny characters in name" do
    lambda {
      new_builder("@#!", [])
    }.should raise_error(Bosh::Cli::InvalidJob, "Job name should be a valid Bosh identifier")
  end  

  it "whines if some configs are missing" do
    add_configs("foo", "a.conf", "b.conf")
    builder = new_builder("foo", [], ["a.conf", "b.conf", "c.conf"])

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidJob, "Some config files required by 'foo' job are missing: c.conf")
  end  

  it "whines if some packages are missing" do
    builder = new_builder("foo", ["foo", "bar", "baz", "app42"], { }, ["foo", "bar"])
    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidJob, "Some packages required by 'foo' job are missing: baz, app42")
  end

  it "whines if there is no spec file" do
    builder = new_builder("foo", ["foo", "bar", "baz", "app42"], { }, ["foo", "bar", "baz", "app42"])
    FileUtils.rm(File.join(@release_dir, "jobs", "foo", "spec"))
    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidJob, "Cannot find spec file for 'foo'")
  end

  it "whines if there is no monit file" do
    add_configs("foo", "a.conf", "b.yml")
    builder = new_builder("foo", ["foo", "bar", "baz", "app42"], ["a.conf", "b.yml"], ["foo", "bar", "baz", "app42"])
    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidJob, "Cannot find monit file for 'foo'")

    add_monit("foo")
    builder.build.should be_true
  end

  it "copies job files" do
    add_configs("foo", "a.conf", "b.yml")
    builder = new_builder("foo", ["foo", "bar", "baz", "app42"], ["a.conf", "b.yml"], ["foo", "bar", "baz", "app42"])
    add_monit("foo")

    builder.copy_files
    builder.copy_manifest

    Dir.chdir(builder.build_dir) do
      File.directory?("config").should be_true
      ["config/a.conf", "config/b.yml"].each do |file|
        File.file?(file).should be_true
      end
      File.file?("job.MF").should be_true
      File.read("job.MF").should == File.read(File.join(@release_dir, "jobs", "foo", "spec"))
      File.exists?("monit").should be_true
    end

    builder.generate_tarball
    File.file?(File.join(@release_dir, "tmp", "jobs", "foo.tgz")).should be_true
  end

end
