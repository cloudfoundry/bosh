require "spec_helper"
require "fileutils"

describe Bosh::Cli::PackageBuilder do

  before(:each) do
    @release_dir = Dir.mktmpdir
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

  def make_builder(name, files, sources_dir = nil)
    Bosh::Cli::PackageBuilder.new({"name" => name, "files" => files}, @release_dir, sources_dir)
  end

  it "whines on missing name" do
    lambda {
      make_builder(" ", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package name is missing")
  end

  it "whines on funny characters in name" do
    lambda {
      make_builder("@#!", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package name should be a valid Bosh identifier")
  end

  it "whines on empty files" do
    lambda {
      make_builder("aa", [])
    }.should raise_error(Bosh::Cli::InvalidPackage, "Package 'aa' doesn't include any files")
  end

  it "is created with name and globs" do
    builder = make_builder("aa", ["1", "*/*"])
    builder.name.should  == "aa"
    builder.globs.should == ["1", "*/*"]
  end

  it "resolves globs and generates signature" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    builder.files.should == [ "lib/1.rb", "lib/2.rb", "README.2", "README.md" ].sort
    builder.signature.should == "3d04140672e5d6bc64d240dac2a003cece11e754"
  end

  it "has stable signature" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")
    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.signature

    builder.reload.signature.should == s1    
  end

  it "changes signature when new file that matches glob is added" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.signature
    add_sources("lib/3.rb")
    builder.reload.signature.should_not == s1

    remove_sources("lib/3.rb")
    builder.reload.signature.should == s1    
  end

  it "changes signature when one of the matched files changes" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")
    File.open("#{@release_dir}/src/lib/1.rb", "w") { |f| f.write("1") }

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.signature

    File.open("#{@release_dir}/src/lib/1.rb", "w+") { |f| f.write("2") }
    
    builder.reload.signature.should_not == s1

    File.open("#{@release_dir}/src/lib/1.rb", "w") { |f| f.write("1") }
    builder.reload.signature.should == s1
  end

  it "changes signature when empty directory added" do
    add_sources("lib/1.rb", "lib/2.rb", "baz")
    builder = make_builder("foo", ["lib/*.rb", "baz", "bar"])
    s1 = builder.signature

    FileUtils.mkdir_p(@release_dir + "/src/bar")
    s2 = builder.reload.signature
    s2.should_not == s1

    add_sources("bar/baz")
    builder.reload.signature.should == s2
    FileUtils.rm_rf(@release_dir + "/src/bar")
    builder.reload.signature.should == s1    
  end

  it "doesn't change signature when files that doesn't match glob is added" do
    add_sources("lib/1.rb", "lib/2.rb", "lib/README.txt", "README.2", "README.md")

    builder = make_builder("A", ["lib/*.rb", "README.*"])
    s1 = builder.signature
    add_sources("lib/a.out")
    builder.reload.signature.should == s1
  end

  it "strips package name from filename" do
    builder = make_builder("foo", ["stuff/**/*.rb"])

    builder.strip_package_name("foo/bar/dir/file.txt").should == "bar/dir/file.txt"
    builder.strip_package_name("bar/dir/file.txt").should == "bar/dir/file.txt"
    builder.strip_package_name("foo").should == "foo"
    builder.strip_package_name("bar/foo").should == "bar/foo"
    builder.strip_package_name("foo/foo").should == "foo"    
    builder.strip_package_name("/foo/foo").should == "/foo/foo"
  end

  it "copies files to build directory" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    builder = make_builder("bar", globs)
    builder.copy_files.should == 5

    builder2 = make_builder("bar", globs, builder.build_dir)

    # Also turned out to be a nice test for directory portability    
    builder.signature.should == builder2.signature
  end
  
  it "generates tarball" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")
    globs = ["foo/**/*", "baz"]

    builder = make_builder("bar", globs)
    builder.generate_tarball.should be_true
  end
  
  it "creates a new version tarball" do
    add_sources("foo/foo.rb", "foo/lib/1.rb", "foo/lib/2.rb", "foo/README", "baz")    
    globs = ["foo/**/*", "baz"]
    builder = make_builder("bar", globs)

    File.exists?(@release_dir + "/packages/bar/bar-1.tgz").should be_false
    builder.build
    File.exists?(@release_dir + "/packages/bar/bar-1.tgz").should be_true

    builder = make_builder("bar", globs)
    builder.build
    v1_signature = builder.signature
    
    File.exists?(@release_dir + "/packages/bar/bar-1.tgz").should be_true
    File.exists?(@release_dir + "/packages/bar/bar-2.tgz").should be_false

    add_sources("foo/3.rb")
    builder = make_builder("bar", globs)
    builder.build

    File.exists?(@release_dir + "/packages/bar/bar-1.tgz").should be_true
    File.exists?(@release_dir + "/packages/bar/bar-2.tgz").should be_true

    remove_sources("foo/3.rb")
    builder = make_builder("bar", globs)    
    builder.guess_version.should == 1

    builder.signature.should == v1_signature
    
    File.exists?(@release_dir + "/packages/bar/bar-1.tgz").should be_true
    File.exists?(@release_dir + "/packages/bar/bar-2.tgz").should be_true
    File.exists?(@release_dir + "/packages/bar/bar-3.tgz").should be_false

    # Now add some metadata
    FileUtils.mkdir("#{@release_dir}/packages/bar/data/")
    File.open("#{@release_dir}/packages/bar/data/packaging", "w") { |f| f.puts("make install") }
    builder = make_builder("bar", globs)
    builder.guess_version.should == 3
    builder.build
    
    File.exists?(@release_dir + "/packages/bar/bar-3.tgz").should be_true

    # And more metadata
    File.open("#{@release_dir}/packages/bar/data/migrations", "w") { |f| f.puts("rake db:migrate") }
    builder = make_builder("bar", globs)
    builder.guess_version.should == 4
    builder.build
    
    File.exists?(@release_dir + "/packages/bar/bar-4.tgz").should be_true    

    # And remove all metadata
    FileUtils.rm_rf("#{@release_dir}/packages/bar/data/")
    builder = make_builder("bar", globs)
    builder.guess_version.should == 1
    builder.build
    File.exists?(@release_dir + "/packages/bar/bar-5.tgz").should be_false
  end

end
