# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::PackageBuilder, "dev build" do

  before(:each) do
    @release_dir = Dir.mktmpdir
    @src_dir = FileUtils.mkdir(File.join(@release_dir, "src"))
    @blobs_dir = FileUtils.mkdir(File.join(@release_dir, "blobs"))
  end

  after(:each) do
    FileUtils.rm_rf(@src_dir)
    FileUtils.rm_rf(@blobs_dir)
  end

  def source_path(filename)
    File.join(@release_dir, "src", filename)
  end

  def add_sources(*files)
    files.each do |file|
      path = source_path(file)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)
    end
  end

  def remove_sources(*files)
    files.each do |file|
      FileUtils.rm(source_path(file))
    end
  end

  def blob_path(filename)
    File.join(@release_dir, "blobs", filename)
  end

  def add_blobs(*files)
    files.each do |file|
      path = blob_path(file)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)
    end
  end

  def remove_blobs(*files)
    files.each do |file|
      FileUtils.rm(blob_path(file))
    end
  end

  def make_builder(name, files, dependencies = [], sources_dir = nil)
    blobstore = mock("blobstore")
    spec = {"name" => name, "files" => files, "dependencies" => dependencies}
    Bosh::Cli::PackageBuilder.new(spec, @release_dir, false, blobstore, sources_dir)
  end

  it "whines on missing name" do
    lambda {
      make_builder(" ", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package name is missing")
  end

  it "whines on funny characters in name" do
    lambda {
      make_builder("@#!", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package name should be a valid BOSH identifier")
  end

  it "whines on empty files" do
    lambda {
      make_builder("aa", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package 'aa' doesn't include any files")
  end

  it "whines on metadata file having the same name as one of package files" do
    lambda {
      builder = make_builder("aa", ["*.rb", "packaging"])
      add_sources("1.rb", "packaging")
      builder.source_files.include?("packaging").should be_true

      File.open("#{@release_dir}/packages/aa/packaging", "w") { |f| f.puts("make install") }

      builder.copy_files
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package 'aa' has 'packaging' file which conflicts with BOSH packaging")
  end

  it "whines on globs not yielding any file names" do
    add_sources("lib/1.rb", "lib/2.rb", "baz")
    builder = make_builder("foo", ["lib/*.rb", "baz", "bar"])

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidPackage, "`foo' has a glob that resolves to an empty file list: bar")
  end

  it "has no way to calculate checksum for not yet generated package" do
    lambda {
      builder = make_builder("aa", ["*.rb", "packaging"])
      add_sources("1.rb", "packaging")
      builder.checksum
    }.should raise_error(RuntimeError, "cannot read checksum for not yet generated package/job")
  end

  it "has a checksum for a generated package" do
    builder = make_builder("aa", ["*.rb"])
    add_sources("1.rb", "2.rb")
    builder.build
    builder.checksum.should =~ /[0-9a-f]+/
  end

  it "is created with name and globs" do
    builder = make_builder("aa", ["1", "*/*"])
    builder.name.should  == "aa"
    builder.globs.should == ["1", "*/*"]
  end

  it "resolves globs and generates fingerprint" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    builder.source_files.should == [ "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort
    builder.fingerprint.should == "72d79bae15daf0f25e5672b9bd753a794107a89f"
  end

  it "has stable fingerprint" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")
    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.fingerprint

    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when new file that matches glob is added" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.fingerprint
    add_sources("lib/3.rb")
    builder.reload.fingerprint.should_not == s1

    remove_sources("lib/3.rb")
    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when one of the matched files changes" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")
    File.open("#{@release_dir}/src/lib/1.rb", "w") { |f| f.write("1") }

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.fingerprint

    File.open("#{@release_dir}/src/lib/1.rb", "w+") { |f| f.write("2") }

    builder.reload.fingerprint.should_not == s1

    File.open("#{@release_dir}/src/lib/1.rb", "w") { |f| f.write("1") }
    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when empty directory added/removed" do
    add_sources("lib/1.rb", "lib/2.rb", "baz")
    builder = make_builder("foo", ["lib/*.rb", "baz", "bar/*"])
    FileUtils.mkdir_p(@release_dir + "/src/bar/zb")

    s1 = builder.fingerprint

    FileUtils.mkdir_p(@release_dir + "/src/bar/zb2")
    s2 = builder.reload.fingerprint
    s2.should_not == s1

    builder.reload.fingerprint.should == s2
    FileUtils.rm_rf(@release_dir + "/src/bar/zb2")
    builder.reload.fingerprint.should == s1
  end

  it "doesn't change fingerprint when files that doesn't match glob is added" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.fingerprint
    add_sources("lib/a.out")
    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when dependencies change" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder1 = make_builder("A", ["lib/*.rb", "README.*"], ["foo", "bar"])
    s1 = builder1.fingerprint
    builder2 = make_builder("A", ["lib/*.rb", "README.*"], ["bar", "foo"])
    s2 = builder2.fingerprint

    s1.should == s2
    builder3 = make_builder("A", ["lib/*.rb", "README.*"], ["bar", "foo", "baz"])
    s3 = builder3.fingerprint
    s3.should_not == s1
  end

  it "copies files to build directory" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    builder = make_builder("bar", globs)
    builder.copy_files.should == 5

    builder2 = make_builder("bar", globs, [], builder.build_dir)

    # Also turned out to be a nice test for directory portability
    builder.fingerprint.should == builder2.fingerprint
  end

  it "generates tarball" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    builder = make_builder("bar", globs)
    builder.generate_tarball.should be_true
  end

  it "can point to either dev or a final version of a package" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    fingerprint = "9c956631508dfc0ccd677434c18e093912682414"

    final_versions = Bosh::Cli::VersionsIndex.new(File.join(@release_dir, ".final_builds", "packages", "bar"))
    dev_versions   = Bosh::Cli::VersionsIndex.new(File.join(@release_dir, ".dev_builds", "packages", "bar"))

    final_versions.add_version(fingerprint, { "version" => "4", "blobstore_id" => "12321" }, "payload")
    dev_versions.add_version(fingerprint, { "version" => "0.7-dev" }, "dev_payload")

    builder = make_builder("bar", globs)
    builder.fingerprint.should == "9c956631508dfc0ccd677434c18e093912682414"

    builder.use_final_version
    builder.version.should == "4"
    builder.tarball_path.should == File.join(@release_dir, ".final_builds", "packages", "bar", "4.tgz")

    builder.use_dev_version
    builder.version.should == "0.7-dev"
    builder.tarball_path.should == File.join(@release_dir, ".dev_builds", "packages", "bar", "0.7-dev.tgz")
  end

  it "creates a new version tarball" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]
    builder = make_builder("bar", globs)

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_false
    builder.build
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_true

    builder = make_builder("bar", globs)
    builder.build
    v1_fingerprint = builder.fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").should be_false

    add_sources("foo/3.rb")
    builder = make_builder("bar", globs)
    builder.build

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").should be_true

    remove_sources("foo/3.rb")
    builder = make_builder("bar", globs)
    builder.build
    builder.version.should == "0.1-dev"

    builder.fingerprint.should == v1_fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.3-dev.tgz").should be_false

    # Now add packaging
    File.open("#{@release_dir}/packages/bar/packaging", "w") { |f| f.puts("make install") }
    builder = make_builder("bar", globs)
    builder.build
    builder.version.should == "0.3-dev"

    # Add prepackaging
    File.open("#{@release_dir}/packages/bar/pre_packaging", "w") { |f| f.puts("exit 0") }
    builder = make_builder("bar", globs)
    builder.build

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.3-dev.tgz").should be_true

    # And remove all
    builder = make_builder("bar", globs)
    builder.build
    builder.version.should == "0.4-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.4-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.5-dev.tgz").should be_false
  end

  it "stops if pre_packaging fails" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    builder = make_builder("bar", globs)
    File.open("#{@release_dir}/packages/bar/pre_packaging", "w") { |f| f.puts("rake db:migrate") }

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidPackage, "`bar' pre-packaging failed")
  end

  it "bumps major dev version in sync with final version" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]
    builder = make_builder("bar", globs)
    builder.build

    builder.version.should == "0.1-dev"

    blobstore = mock("blobstore")
    blobstore.should_receive(:create).and_return("object_id")
    final_builder = Bosh::Cli::PackageBuilder.new({"name" => "bar", "files" => globs}, @release_dir, true, blobstore)
    final_builder.build

    final_builder.version.should == 1

    add_sources("foo/foo15.rb")
    builder2 = make_builder("bar", globs)
    builder2.build
    builder2.version.should == "1.1-dev"
  end

  it "uses the appropriate final version for bumping a dev version" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]
    builder = make_builder("bar", globs)
    final_builds_dir = File.join(@release_dir, ".final_builds", "packages", "bar")
    builder.build

    final_index = Bosh::Cli::VersionsIndex.new(final_builds_dir)
    final_index.add_version("deadbeef", { "version" => 34}, "payload")

    add_sources("foo/foo14.rb")
    builder.reload.build
    builder.version.should == "34.1-dev"

    final_index.add_version("deadbeef2", { "version" => 37}, "payload")

    add_sources("foo/foo15.rb")
    builder.reload.build
    builder.version.should == "37.1-dev"

    add_sources("foo/foo16.rb")
    builder.reload.build
    builder.version.should == "37.2-dev"

    FileUtils.rm_rf(final_builds_dir)
    final_index = Bosh::Cli::VersionsIndex.new(final_builds_dir)
    final_index.add_version("deadbeef3", { "version" => 34}, "payload")

    add_sources("foo/foo17.rb")
    builder.reload.build
    builder.version.should == "34.2-dev"
  end

  it "whines on attempt to create final build if not matched by existing final or dev build" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    blobstore = mock("blobstore")
    blobstore.should_receive(:create).and_return("object_id")

    final_builder = Bosh::Cli::PackageBuilder.new({"name" => "bar", "files" => globs}, @release_dir, true, blobstore)
    lambda {
      final_builder.build
    }.should raise_error(Bosh::Cli::CliExit)

    builder = make_builder("bar", globs)
    builder.build

    builder.version.should == "0.1-dev"

    final_builder2 = Bosh::Cli::PackageBuilder.new({"name" => "bar", "files" => globs}, @release_dir, true, blobstore)
    final_builder2.build
    final_builder2.version.should == 1

    add_sources("foo/foo15.rb")
    final_builder3 = Bosh::Cli::PackageBuilder.new({"name" => "bar", "files" => globs}, @release_dir, true, blobstore)
    lambda {
      final_builder3.build
    }.should raise_error(Bosh::Cli::CliExit)
  end

  it "includes dotfiles in a fingerprint" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    builder.source_files.should == [ "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort

    builder.fingerprint.should == "72d79bae15daf0f25e5672b9bd753a794107a89f"

    add_sources("lib/.zb.rb")
    builder.reload

    builder.source_files.should == [ "lib/.zb.rb", "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort
    builder.fingerprint.should == "80a36ed79aa5c4aa23b6c21895107103c9673e99"

    remove_sources("lib/.zb.rb")
    builder.reload

    builder.source_files.should == [ "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort
    builder.fingerprint.should == "72d79bae15daf0f25e5672b9bd753a794107a89f"
  end

  it "supports dry run" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]
    builder = make_builder("bar", globs)
    builder.dry_run = true
    builder.build

    builder.version.should == "0.1-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_false

    builder.dry_run = false
    builder.reload.build
    builder.version.should == "0.1-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_true

    blobstore = mock("blobstore")
    blobstore.should_not_receive(:create)
    final_builder = Bosh::Cli::PackageBuilder.new({"name" => "bar", "files" => globs}, @release_dir, true, blobstore)
    final_builder.dry_run = true
    final_builder.build

    final_builder.version.should == "0.1-dev" # Hasn't been promoted b/c of dry run

    add_sources("foo/foo15.rb")
    builder2 = make_builder("bar", globs)
    builder2.dry_run = true
    builder2.build
    builder2.version.should == "0.2-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").should be_true
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").should be_false
  end

  it "resolves files using blob" do
    add_blobs("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    builder.blob_files.should == [ "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort
    builder.fingerprint.should == "72d79bae15daf0f25e5672b9bd753a794107a89f"
  end

  it "resolves files using both blob and source" do
    add_sources("lib/1.rb", "lib/2.rb")
    add_blobs("lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])

    builder.source_files.should == [ "lib/1.rb", "lib/2.rb"].sort
    builder.blob_files.should == [ "README.2", "README.md" ].sort
    builder.files.should == [ "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort
    builder.fingerprint.should == "72d79bae15daf0f25e5672b9bd753a794107a89f"
  end

  it "should keep same fingerprint moving packages from source_dir to blob_dir" do

    # compute fingerprint when all the files are 'blob'
    add_blobs("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")
    builder = make_builder("A", ["lib/*.rb", "README.*"])
    blob_fingerprint = builder.fingerprint
    remove_blobs("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    # compute fingerprint when all the files are in 'source'
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")
    builder = make_builder("A", ["lib/*.rb", "README.*"])
    blob_sources = builder.fingerprint
    remove_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder.fingerprint.should == blob_fingerprint
  end

end
