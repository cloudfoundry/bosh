# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::PackageBuilder, "dev build" do

  before(:each) do
    @release_dir = Dir.mktmpdir
    FileUtils.mkdir(File.join(@release_dir, "src"))
    FileUtils.mkdir(File.join(@release_dir, "blobs"))
    FileUtils.mkdir(File.join(@release_dir, "src_alt"))
  end

  def add_file(dir, path, contents = nil)
    full_path = File.join(@release_dir, dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    if contents
      File.open(full_path, "w") { |f| f.write(contents) }
    else
      FileUtils.touch(full_path)
    end
  end

  def remove_file(dir, path)
    FileUtils.rm(File.join(@release_dir, dir, path))
  end

  def add_files(dir, names)
    names.each { |name| add_file(dir, name) }
  end

  def remove_files(dir, names)
    names.each { |name| remove_file(dir, name) }
  end

  def make_builder(name, files, dependencies = [], sources_dir = nil)
    blobstore = double("blobstore")
    spec = {
      "name" => name,
      "files" => files,
      "dependencies" => dependencies
    }

    Bosh::Cli::PackageBuilder.new(spec, @release_dir,
                                  false, blobstore, sources_dir)
  end

  it "whines on missing name" do
    lambda {
      make_builder(" ", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package name is missing")
  end

  it "whines on funny characters in name" do
    lambda {
      make_builder("@#!", [])
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package name should be a valid BOSH identifier")
  end

  it "whines on empty files" do
    lambda {
      make_builder("aa", [])
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package 'aa' doesn't include any files")
  end

  it "whines on metadata file having the same name as one of package files" do
    lambda {
      builder = make_builder("aa", %w(*.rb packaging))

      add_files("src", %w(1.rb packaging))

      builder.glob_matches.size.should == 2
      add_file("packages", "aa/packaging", "make install")

      builder.copy_files
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package 'aa' has 'packaging' file which " +
                         "conflicts with BOSH packaging")
  end

  it "whines on globs not yielding any file names" do
    add_files("src",  %w(lib/1.rb lib/2.rb baz))
    builder = make_builder("foo", %w(lib/*.rb baz bar))

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package `foo' has a glob that resolves " +
                         "to an empty file list: bar")
  end

  it "has no way to calculate checksum for not yet generated package" do
    lambda {
      builder = make_builder("aa", %w(*.rb packaging))
      add_files("src", %w(1.rb packaging))
      builder.checksum
    }.should raise_error(RuntimeError,
                         "cannot read checksum for not yet " +
                         "generated package/job")
  end

  it "has a checksum for a generated package" do
    builder = make_builder("aa", %w(*.rb))
    add_files("src", %w(1.rb 2.rb))
    builder.build
    builder.checksum.should =~ /[0-9a-f]+/
  end

  it "is created with name and globs" do
    builder = make_builder("aa", %w(1 */*))
    builder.name.should  == "aa"
    builder.globs.should == %w(1 */*)
  end

  it "resolves globs and generates fingerprint" do
    add_files("src", %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder("A", %w(lib/*.rb README.*))
    builder.glob_matches.size.should == 4
    builder.fingerprint.should == "397a99ccd267ebc9bcc632b746db2cd5b29db050"
  end

  it "has stable fingerprint" do
    add_files("src", %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))
    builder = make_builder("A", %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when new file that matches glob is added" do
    add_files("src", %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder("A", %w(lib/*.rb README.*))
    s1 = builder.fingerprint
    add_files("src", %w(lib/3.rb))
    builder.reload.fingerprint.should_not == s1

    remove_files("src", %w(lib/3.rb))
    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when one of the matched files changes" do
    add_files("src", %w(lib/2.rb lib/README.txt README.2 README.md))
    add_file("src", "lib/1.rb", "1")

    builder = make_builder("A", %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file("src", "lib/1.rb", "2")
    builder.reload.fingerprint.should_not == s1

    add_file("src", "lib/1.rb", "1")
    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when empty directory added/removed" do
    add_files("src", %w(lib/1.rb lib/2.rb baz))
    builder = make_builder("foo", %w(lib/*.rb baz bar/*))
    FileUtils.mkdir_p(File.join(@release_dir, "src", "bar", "zb"))

    s1 = builder.fingerprint

    FileUtils.mkdir_p(File.join(@release_dir, "src", "bar", "zb2"))
    s2 = builder.reload.fingerprint
    s2.should_not == s1

    FileUtils.rm_rf(File.join(@release_dir, "src", "bar", "zb2"))
    builder.reload.fingerprint.should == s1
  end

  it "doesn't change fingerprint when files that doesn't match glob is added" do
    add_files("src", %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))
    builder = make_builder("A", %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file("src", "lib/a.out")
    builder.reload.fingerprint.should == s1
  end

  it "changes fingerprint when dependencies change" do
    add_files("src", %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder1 = make_builder("A", %w(lib/*.rb README.*), %w(foo bar))
    s1 = builder1.fingerprint
    builder2 = make_builder("A", %w(lib/*.rb README.*), %w(bar foo))
    s2 = builder2.fingerprint
    s1.should == s2 # Order doesn't matter

    builder3 = make_builder("A", %w(lib/*.rb README.*), %w(bar foo baz))
    s3 = builder3.fingerprint
    s3.should_not == s1 # Set does matter
  end

  it "copies files to build directory" do
    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    builder = make_builder("bar", globs)
    builder.copy_files.should == 5

    builder2 = make_builder("bar", globs, [], builder.build_dir)

    # Also turned out to be a nice test for directory portability
    builder.fingerprint.should == builder2.fingerprint
  end

  it "generates tarball" do
    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    builder = make_builder("bar", %w(foo/**/* baz))
    builder.generate_tarball.should be(true)
  end

  it "can point to either dev or a final version of a package" do
    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    fingerprint = "86e8d5f5530a89659f588f5884fe8c13e639d94b"

    final_versions = Bosh::Cli::VersionsIndex.new(
        File.join(@release_dir, ".final_builds", "packages", "bar"))
    dev_versions   = Bosh::Cli::VersionsIndex.new(
        File.join(@release_dir, ".dev_builds", "packages", "bar"))

    final_versions.add_version(fingerprint,
                               { "version" => "4", "blobstore_id" => "12321" },
                               get_tmp_file_path("payload"))
    dev_versions.add_version(fingerprint,
                             { "version" => "0.7-dev" },
                             get_tmp_file_path("dev_payload"))

    builder = make_builder("bar", globs)
    builder.fingerprint.should == fingerprint

    builder.use_final_version
    builder.version.should == "4"
    builder.tarball_path.should == File.join(
        @release_dir, ".final_builds", "packages", "bar", "4.tgz")

    builder.use_dev_version
    builder.version.should == "0.7-dev"
    builder.tarball_path.should == File.join(
        @release_dir, ".dev_builds", "packages", "bar", "0.7-dev.tgz")
  end

  it "creates a new version tarball" do
    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder("bar", globs)

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(false)
    builder.build
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(true)

    builder = make_builder("bar", globs)
    builder.build
    v1_fingerprint = builder.fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").
        should be(false)

    add_file("src", "foo/3.rb")
    builder = make_builder("bar", globs)
    builder.build

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").
        should be(true)

    remove_file("src", "foo/3.rb")
    builder = make_builder("bar", globs)
    builder.build
    builder.version.should == "0.1-dev"

    builder.fingerprint.should == v1_fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.3-dev.tgz").
        should be(false)

    # Now add packaging
    add_file("packages", "bar/packaging", "make install")
    builder = make_builder("bar", globs)
    builder.build
    builder.version.should == "0.3-dev"

    # Add prepackaging
    add_file("packages", "bar/pre_packaging", "exit 0")
    builder = make_builder("bar", globs)
    builder.build

    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.3-dev.tgz").
        should be(true)

    # And remove all
    builder = make_builder("bar", globs)
    builder.build
    builder.version.should == "0.4-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.4-dev.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.5-dev.tgz").
        should be(false)
  end

  it "stops if pre_packaging fails" do
    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    builder = make_builder("bar", globs)
    add_file("packages", "bar/pre_packaging", "exit 1")

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "`bar' pre-packaging failed")
  end

  it "prevents building final version with src alt" do
    spec = {
      "name" => "bar",
      "files" => "foo/**/*"
    }

    lambda {
      Bosh::Cli::PackageBuilder.new(spec, @release_dir,
                                    true, double("blobstore"))
    }.should raise_error(/Please remove `src_alt' first/)
  end

  it "bumps major dev version in sync with final version" do
    FileUtils.rm_rf(File.join(@release_dir, "src_alt"))

    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder("bar", globs)
    builder.build

    builder.version.should == "0.1-dev"

    blobstore = double("blobstore")
    blobstore.should_receive(:create).and_return("object_id")
    final_builder = Bosh::Cli::PackageBuilder.new({ "name" => "bar",
                                                    "files" => globs },
                                                  @release_dir,
                                                  true, blobstore)
    final_builder.build
    final_builder.version.should == 1

    add_file("src", "foo/foo15.rb")
    builder2 = make_builder("bar", globs)
    builder2.build
    builder2.version.should == "1.1-dev"
  end

  it "uses the appropriate final version for bumping a dev version" do
    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder("bar", globs)
    final_builds_dir = File.join(@release_dir,
                                 ".final_builds", "packages", "bar")
    builder.build

    final_index = Bosh::Cli::VersionsIndex.new(final_builds_dir)
    final_index.add_version("deadbeef",
                            { "version" => 34 },
                            get_tmp_file_path("payload"))

    add_file("src", "foo/foo14.rb")
    builder.reload.build
    builder.version.should == "34.1-dev"

    final_index.add_version("deadbeef2",
                            { "version" => 37 },
                            get_tmp_file_path("payload"))

    add_file("src", "foo/foo15.rb")
    builder.reload.build
    builder.version.should == "37.1-dev"

    add_file("src", "foo/foo16.rb")
    builder.reload.build
    builder.version.should == "37.2-dev"

    FileUtils.rm_rf(final_builds_dir)
    final_index = Bosh::Cli::VersionsIndex.new(final_builds_dir)
    final_index.add_version("deadbeef3",
                            { "version" => 34 },
                            get_tmp_file_path("payload"))

    add_file("src", "foo/foo17.rb")
    builder.reload.build
    builder.version.should == "34.2-dev"
  end

  it "whines on attempt to create final build if not matched " +
     "by existing final or dev build" do
    FileUtils.rm_rf(File.join(@release_dir, "src_alt"))

    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    blobstore = double("blobstore")
    blobstore.should_receive(:create).and_return("object_id")

    final_builder = Bosh::Cli::PackageBuilder.new(
      { "name" => "bar", "files" => globs }, @release_dir, true, blobstore)
    lambda {
      final_builder.build
    }.should raise_error(Bosh::Cli::CliError)

    builder = make_builder("bar", globs)
    builder.build

    builder.version.should == "0.1-dev"

    final_builder2 = Bosh::Cli::PackageBuilder.new(
        { "name" => "bar", "files" => globs }, @release_dir, true, blobstore)
    final_builder2.build
    final_builder2.version.should == 1

    add_file("src", "foo/foo15.rb")
    final_builder3 = Bosh::Cli::PackageBuilder.new(
      { "name" => "bar", "files" => globs }, @release_dir, true, blobstore)
    lambda {
      final_builder3.build
    }.should raise_error(Bosh::Cli::CliError)
  end

  it "includes dotfiles in a fingerprint" do
    add_files("src", %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder("A", %w(lib/*.rb README.*))
    builder.glob_matches.size.should == 4
    builder.fingerprint.should == "397a99ccd267ebc9bcc632b746db2cd5b29db050"

    add_file("src", "lib/.zb.rb")
    builder.reload

    builder.glob_matches.size.should == 5
    builder.fingerprint.should == "351b3bb8dc430e58a3264bcfb5c9c19c06ece4af"

    remove_file("src", "lib/.zb.rb")
    builder.reload

    builder.glob_matches.size.should == 4
    builder.fingerprint.should == "397a99ccd267ebc9bcc632b746db2cd5b29db050"
  end

  it "supports dry run" do
    FileUtils.rm_rf(File.join(@release_dir, "src_alt"))

    add_files("src", %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder("bar", globs)
    builder.dry_run = true
    builder.build

    builder.version.should == "0.1-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(false)

    builder.dry_run = false
    builder.reload.build
    builder.version.should == "0.1-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(true)

    blobstore = double("blobstore")
    blobstore.should_not_receive(:create)
    final_builder = Bosh::Cli::PackageBuilder.new(
      { "name" => "bar", "files" => globs }, @release_dir, true, blobstore)
    final_builder.dry_run = true
    final_builder.build

    # Hasn't been promoted b/c of dry run
    final_builder.version.should == "0.1-dev"

    add_file("src", "foo/foo15.rb")
    builder2 = make_builder("bar", globs)
    builder2.dry_run = true
    builder2.build
    builder2.version.should == "0.2-dev"
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.1-dev.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/0.2-dev.tgz").
        should be(false)
  end

  it "uses blobs directory to look up files as well" do
    add_files("src", %w(lib/1.rb lib/2.rb))
    add_files("blobs", %w(lib/README.txt README.2 README.md))

    builder = make_builder("A", %w(lib/*.rb README.*))
    builder.glob_matches.size.should == 4
    builder.fingerprint.should == "397a99ccd267ebc9bcc632b746db2cd5b29db050"
  end

  it "moving files to blobs directory doesn't change fingerprint" do
    add_file("src", "README.txt", "README contents")
    add_file("src", "README.md", "README contents 2")
    add_file("src", "lib/1.rb", "puts 'Hello world'")
    add_file("src", "lib/2.rb", "puts 'Bye world'")

    builder = make_builder("A", %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    FileUtils.mkdir_p(File.join(@release_dir, "blobs", "lib"))

    FileUtils.mv(File.join(@release_dir, "src", "lib", "1.rb"),
                 File.join(@release_dir, "blobs", "lib", "1.rb"))

    s2 = builder.reload.fingerprint
    s2.should == s1
  end

  it "supports alternative src directory" do
    add_file("src", "README.txt", "README contents")
    add_file("src", "lib/1.rb", "puts 'Hello world'")
    add_file("src", "lib/2.rb", "puts 'Goodbye world'")

    builder = make_builder("A", %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file("src_alt", "README.txt", "README contents")
    add_file("src_alt", "lib/1.rb", "puts 'Hello world'")
    add_file("src_alt", "lib/2.rb", "puts 'Goodbye world'")

    remove_files("src", %w(lib/1.rb))
    builder.reload.fingerprint.should == s1
  end

  it "checks if glob top level dir is present in src_alt but doesn't match" do
    add_file("src", "README.txt", "README contents")
    add_file("src", "lib/1.rb", "puts 'Hello world'")
    add_file("src", "lib/2.rb", "puts 'Goodbye world'")

    builder = make_builder("A", %w(lib/*.rb README.*))

    FileUtils.mkdir(File.join(@release_dir, "src_alt", "lib"))

    lambda {
      builder.fingerprint
    }.should raise_error("Package `A' has a glob that doesn't match " +
                         "in `src_alt' but matches in `src'. However " +
                         "`src_alt/lib' exists, so this might be an error.")
  end

  it "doesn't allow glob to match files under more than one source directory" do
    add_file("src", "README.txt", "README contents")
    add_file("src", "lib/1.rb", "puts 'Hello world'")

    builder = make_builder("A", %w(lib/*.rb README.*))
    lambda {
      builder.fingerprint
    }.should_not raise_error

    add_file("src_alt", "README.txt", "README contents")
    remove_files("src", %w(README.txt lib/1.rb))

    lambda {
      builder.reload.fingerprint
    }.should raise_error("Package `A' has a glob that resolves to " +
                         "an empty file list: lib/*.rb")
  end

  it "doesn't include the same path twice" do
    add_file("src", "test/foo/README.txt", "README contents")
    add_file("src", "test/foo/NOTICE.txt", "NOTICE contents")

    fp1 = make_builder("A", %w(test/**/*)).fingerprint

    remove_file("src", "test/foo/NOTICE.txt")
    add_file("blobs", "test/foo/NOTICE.txt", "NOTICE contents")

    File.directory?(File.join(@release_dir, "src", "test", "foo")).
      should be(true)

    fp2 = make_builder("A", %w(test/**/*)).fingerprint

    fp1.should == fp2
  end

end
