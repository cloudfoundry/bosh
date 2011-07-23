require "spec_helper"
require "fileutils"

describe Bosh::Cli::JobBuilder do

  before(:each) do
    @release_dir = Dir.mktmpdir
    at_exit { FileUtils.rm_rf(@release_dir) }
  end

  def new_builder(name, packages = [], templates = { }, built_packages = [], create_spec = true, final = false, blobstore = mock("blobstore"))
    # Workaround for Hash requirement
    if templates.is_a?(Array)
      templates = templates.inject({ }) { |h, e| h[e] = e; h }
    end

    spec = {
      "name"       => name,
      "packages"   => packages,
      "templates"  => templates
    }
    add_spec(name) if create_spec

    Bosh::Cli::JobBuilder.new(spec, @release_dir, final, blobstore, built_packages)
  end

  def add_file(job_name, file, contents = nil)
    job_dir = File.join(@release_dir, "jobs", job_name)
    file_path = File.join(job_dir, file)
    FileUtils.mkdir_p(File.dirname(file_path))
    FileUtils.touch(file_path)
    if contents
      File.open(file_path, "w") { |f| f.write(contents) }
    end
  end

  def add_spec(job_name)
    add_file(job_name, "spec")
  end

  def add_monit(job_name)
    add_file(job_name, "monit")
  end

  def add_templates(job_name, *files)
    job_template_path = File.join(@release_dir, "jobs", job_name, "templates")
    FileUtils.mkdir_p(job_template_path)

    files.each do |file|
      add_file(job_name, "templates/#{file}")
    end
  end

  it "creates a new builder" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")
    builder = new_builder("foo", ["foo", "bar", "baz"], ["a.conf", "b.yml"], ["foo", "bar", "baz"])
    builder.packages.should    == ["foo", "bar", "baz"]
    builder.templates.should     =~ ["a.conf", "b.yml"]
    builder.release_dir.should == @release_dir
  end

  it "has a fingerprint" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")
    builder = new_builder("foo", ["foo", "bar"], ["a.conf", "b.yml"], ["foo", "bar"])
    builder.fingerprint.should == "8c648313f029ee50612bfbb99b507eef1eb6f6c0"
  end

  it "has a stable portable fingerprint" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")
    b1 = new_builder("foo", ["foo", "bar"], ["a.conf", "b.yml"], ["foo", "bar"])
    f1 = b1.fingerprint
    b1.reload.fingerprint.should == f1

    b2 = new_builder("foo", ["foo", "bar"], ["a.conf", "b.yml"], ["foo", "bar"])
    b2.fingerprint.should == f1
  end

  it "changes fingerprint when new template file is added" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")

    b1 = new_builder("foo", ["foo", "bar"], ["a.conf", "b.yml"], ["foo", "bar"])
    f1 = b1.fingerprint

    add_templates("foo", "baz")
    b2 = new_builder("foo", ["foo", "bar"], ["a.conf", "b.yml", "baz"], ["foo", "bar"])
    b2.fingerprint.should_not == f1
  end

  it "changes fingerprint when template files is changed" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")

    b1 = new_builder("foo", ["foo", "bar"], ["a.conf", "b.yml"], ["foo", "bar"])
    f1 = b1.fingerprint

    add_file("foo", "templates/a.conf", "bzz")
    b1.reload.fingerprint.should_not == f1
  end

  it "can read template file names from hash" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")
    builder = new_builder("foo", ["foo", "bar", "baz"], {"a.conf" => 1, "b.yml" => 2}, ["foo", "bar", "baz"])
    builder.templates.should =~ ["a.conf", "b.yml"]
  end

  it "whines if name is blank" do
    lambda {
      new_builder("")
    }.should raise_error(Bosh::Cli::InvalidJob, "Job name is missing")
  end

  it "whines on funny characters in name" do
    lambda {
      new_builder("@#!", [])
    }.should raise_error(Bosh::Cli::InvalidJob, "`@#!' is not a valid Bosh identifier")
  end

  it "whines if some templates are missing" do
    add_templates("foo", "a.conf", "b.conf")

    lambda {
      new_builder("foo", [], ["a.conf", "b.conf", "c.conf"])
    }.should raise_error(Bosh::Cli::InvalidJob, "Some template files required by 'foo' job are missing: c.conf")
  end

  it "whines if some packages are missing" do
    lambda {
      new_builder("foo", ["foo", "bar", "baz", "app42"], { }, ["foo", "bar"])
    }.should raise_error(Bosh::Cli::InvalidJob, "Some packages required by 'foo' job are missing: baz, app42")
  end

  it "whines if there is no spec file" do
    lambda {
      new_builder("foo", ["foo", "bar", "baz", "app42"], { }, ["foo", "bar", "baz", "app42"], false)
    }.should raise_error(Bosh::Cli::InvalidJob, "Cannot find spec file for 'foo'")
  end

  it "whines if there is no monit file" do
    lambda {
      add_templates("foo", "a.conf", "b.yml")
      new_builder("foo", ["foo", "bar", "baz", "app42"], ["a.conf", "b.yml"], ["foo", "bar", "baz", "app42"])
    }.should raise_error(Bosh::Cli::InvalidJob, "Cannot find monit file for 'foo'")

    add_monit("foo")
    lambda {
      new_builder("foo", ["foo", "bar", "baz", "app42"], ["a.conf", "b.yml"], ["foo", "bar", "baz", "app42"])
    }.should_not raise_error
  end

  it "supports preparation script" do
    spec = {
      "name"       => "foo",
      "packages"   => ["bar", "baz"],
      "templates"  => ["a.conf", "b.yml"]
    }
    spec_yaml = YAML.dump(spec)

    script = <<-SCRIPT.gsub(/^\s*/, "")
    #!/bin/sh
    mkdir templates
    touch templates/a.conf
    touch templates/b.yml
    echo '#{spec_yaml}' > spec
    touch monit
    SCRIPT

    add_file("foo", "prepare", script)
    script_path = File.join(@release_dir, "jobs", "foo", "prepare")
    FileUtils.chmod(0755, script_path)
    Bosh::Cli::JobBuilder.run_prepare_script(script_path)

    builder = new_builder("foo", ["bar", "baz"], ["a.conf", "b.yml"], ["foo", "bar", "baz", "app42"], false)
    builder.copy_files.should == 4

    Dir.chdir(builder.build_dir) do
      File.directory?("templates").should be_true
      ["templates/a.conf", "templates/b.yml"].each do |file|
        File.file?(file).should be_true
      end
      File.file?("job.MF").should be_true
      File.read("job.MF").should == File.read(File.join(@release_dir, "jobs", "foo", "spec"))
      File.exists?("monit").should be_true
      File.exists?("prepare").should be_false
    end
  end

  it "copies job files" do
    add_templates("foo", "a.conf", "b.yml")
    add_monit("foo")
    builder = new_builder("foo", ["foo", "bar", "baz", "app42"], ["a.conf", "b.yml"], ["foo", "bar", "baz", "app42"])

    builder.copy_files.should == 4

    Dir.chdir(builder.build_dir) do
      File.directory?("templates").should be_true
      ["templates/a.conf", "templates/b.yml"].each do |file|
        File.file?(file).should be_true
      end
      File.file?("job.MF").should be_true
      File.read("job.MF").should == File.read(File.join(@release_dir, "jobs", "foo", "spec"))
      File.exists?("monit").should be_true
    end
  end

  it "generates tarball" do
    add_templates("foo", "bar", "baz")
    add_monit("foo")

    builder = new_builder("foo", ["p1", "p2"], ["bar", "baz"], ["p1", "p2"])
    builder.generate_tarball.should be_true
  end

  it "supports versioning" do
    add_templates("foo", "bar", "baz")
    add_monit("foo")

    builder = new_builder("foo", [], ["bar", "baz"], [])

    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_false
    builder.build
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_true
    v1_fingerprint = builder.fingerprint

    add_templates("foo", "zb.yml")
    builder = new_builder("foo", [], ["bar", "baz", "zb.yml"], [])
    builder.build

    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.2-dev.tgz").should be_true

    builder = new_builder("foo", [], ["bar", "baz"], [])
    builder.build
    builder.version.should == "0.1-dev"

    builder.fingerprint.should == v1_fingerprint
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.2-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.3-dev.tgz").should be_false
  end

  it "can point to either dev or a final version of a job" do
    add_templates("foo", "bar", "baz")
    add_monit("foo")
    fingerprint = "ea9931b04f6a736b8806d2f56c68096fb4dc1ee6"

    final_versions = Bosh::Cli::VersionsIndex.new(File.join(@release_dir, ".final_builds", "jobs", "foo"))
    dev_versions   = Bosh::Cli::VersionsIndex.new(File.join(@release_dir, ".dev_builds", "jobs", "foo"))

    final_versions.add_version(fingerprint, { "version" => "4", "blobstore_id" => "12321" }, "payload")
    dev_versions.add_version(fingerprint, { "version" => "0.7-dev" }, "dev_payload")

    builder = new_builder("foo", [], ["bar", "baz"], [])

    builder.fingerprint.should == fingerprint

    builder.use_final_version
    builder.version.should == "4"
    builder.tarball_path.should == File.join(@release_dir, ".final_builds", "jobs", "foo", "4.tgz")

    builder.use_dev_version
    builder.version.should == "0.7-dev"
    builder.tarball_path.should == File.join(@release_dir, ".dev_builds", "jobs", "foo", "0.7-dev.tgz")
  end

  it "bumps major dev version in sync with final version" do
    add_templates("foo", "bar", "baz")
    add_monit("foo")

    builder = new_builder("foo", [], ["bar", "baz"], [])
    builder.build

    builder.version.should == "0.1-dev"

    blobstore = mock("blobstore")
    blobstore.should_receive(:create).and_return("object_id")
    final_builder = new_builder("foo", [], ["bar", "baz"], [], true, true, blobstore)
    final_builder.build

    final_builder.version.should == 1

    add_templates("foo", "bzz")
    builder2 = new_builder("foo", [], ["bar", "baz", "bzz"], [])
    builder2.build
    builder2.version.should == "1.1-dev"
  end

  it "whines on attempt to create final build if not matched by existing final or dev build" do
    add_templates("foo", "bar", "baz")
    add_monit("foo")

    blobstore = mock("blobstore")

    final_builder = new_builder("foo", [], ["bar", "baz"], [], true, true, blobstore)
    lambda {
      final_builder.build
    }.should raise_error(Bosh::Cli::CliExit)

    dev_builder = new_builder("foo", [], ["bar", "baz"], [], true, false, blobstore)
    dev_builder.build

    final_builder2 = new_builder("foo", [], ["bar", "baz"], [], true, true, blobstore)
    blobstore.should_receive(:create)
    final_builder2.build

    add_templates("foo", "bzz")
    final_builder3 = new_builder("foo", [], ["bar", "baz", "bzz"], [], true, true, blobstore)

    lambda {
      final_builder3.build
    }.should raise_error(Bosh::Cli::CliExit)
  end

  it "allows template subdirectories" do
    add_templates("foo", "foo/bar", "bar/baz")
    add_monit("foo")

    blobstore = mock("blobstore")
    builder = new_builder("foo", [], ["foo/bar", "bar/baz"], [], true, false, blobstore)
    builder.build

    Dir.chdir(builder.build_dir) do
      File.directory?("templates").should be_true
      ["templates/foo/bar", "templates/bar/baz"].each do |file|
        File.file?(file).should be_true
      end
    end
  end

  it "supports dry run" do
    add_templates("foo", "bar", "baz")
    add_monit("foo")

    builder = new_builder("foo", [], ["bar", "baz"], [])
    builder.dry_run = true
    builder.build

    builder.version.should == "0.1-dev"
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_false

    builder.dry_run = false
    builder.reload.build
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_true

    blobstore = mock("blobstore")
    blobstore.should_not_receive(:create)
    final_builder = new_builder("foo", [], ["bar", "baz"], [], true, true, blobstore)
    final_builder.dry_run = true
    final_builder.build

    final_builder.version.should == "0.1-dev" # As it shouldn't be promoted during dry run
    File.exists?(@release_dir + "/.final_builds/jobs/foo/1.tgz").should be_false

    add_templates("foo", "bzz")
    builder2 = new_builder("foo", [], ["bar", "baz", "bzz"], [])
    builder2.dry_run = true
    builder2.build
    builder2.version.should == "0.2-dev"
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/jobs/foo/0.2-dev.tgz").should be_false
  end

end
