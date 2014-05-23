require 'spec_helper'

describe Bosh::Cli::PackageBuilder, 'dev build' do
  before do
    @release_dir = Dir.mktmpdir
    FileUtils.mkdir(File.join(@release_dir, 'src'))
    FileUtils.mkdir(File.join(@release_dir, 'blobs'))
    FileUtils.mkdir(File.join(@release_dir, 'src_alt'))
  end

  def add_file(dir, path, contents = nil)
    full_path = File.join(@release_dir, dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    if contents
      File.open(full_path, 'w') { |f| f.write(contents) }
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
    blobstore = double('blobstore')
    spec = {
      'name' => name,
      'files' => files,
      'dependencies' => dependencies
    }

    Bosh::Cli::PackageBuilder.new(spec, @release_dir,
                                  false, blobstore, sources_dir)
  end

  it 'whines on missing name' do
    lambda {
      make_builder(' ', [])
    }.should raise_error(Bosh::Cli::InvalidPackage, 'Package name is missing')
  end

  it 'whines on funny characters in name' do
    lambda {
      make_builder('@#!', [])
    }.should raise_error(Bosh::Cli::InvalidPackage,
      'Package name should be a valid BOSH identifier')
  end

  it 'whines on empty files' do
    lambda {
      make_builder('aa', [])
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package 'aa' doesn't include any files")
  end

  it 'whines on metadata file having the same name as one of package files' do
    lambda {
      builder = make_builder('aa', %w(*.rb packaging))

      add_files('src', %w(1.rb packaging))

      builder.glob_matches.size.should == 2
      add_file('packages', 'aa/packaging', 'make install')

      builder.copy_files
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package 'aa' has 'packaging' file which " +
                           'conflicts with BOSH packaging')
  end

  it 'whines on globs not yielding any file names' do
    add_files('src',  %w(lib/1.rb lib/2.rb baz))
    builder = make_builder('foo', %w(lib/*.rb baz bar))

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "Package `foo' has a glob that resolves " +
                           'to an empty file list: bar')
  end

  it 'has no way to calculate checksum for not yet generated package' do
    lambda {
      builder = make_builder('aa', %w(*.rb packaging))
      add_files('src', %w(1.rb packaging))
      builder.checksum
    }.should raise_error(RuntimeError,
                         'cannot read checksum for not yet ' +
                           'generated package/job')
  end

  it 'has a checksum for a generated package' do
    builder = make_builder('aa', %w(*.rb))
    add_files('src', %w(1.rb 2.rb))
    builder.build
    builder.checksum.should =~ /[0-9a-f]+/
  end

  it 'is created with name and globs' do
    builder = make_builder('aa', %w(1 */*))
    builder.name.should  == 'aa'
    builder.globs.should == %w(1 */*)
  end

  it 'resolves globs and generates fingerprint' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    builder.glob_matches.size.should == 4
    builder.fingerprint.should == '167bd0b339d78606cf00a8740791b54b1cf619a6'
  end

  it 'has stable fingerprint' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))
    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    builder.reload.fingerprint.should == s1
  end

  it 'changes fingerprint when new file that matches glob is added' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint
    add_files('src', %w(lib/3.rb))
    builder.reload.fingerprint.should_not == s1

    remove_files('src', %w(lib/3.rb))
    builder.reload.fingerprint.should == s1
  end

  it 'changes fingerprint when one of the matched files changes' do
    add_files('src', %w(lib/2.rb lib/README.txt README.2 README.md))
    add_file('src', 'lib/1.rb', '1')

    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file('src', 'lib/1.rb', '2')
    builder.reload.fingerprint.should_not == s1

    add_file('src', 'lib/1.rb', '1')
    builder.reload.fingerprint.should == s1
  end

  it 'changes fingerprint when empty directory added/removed' do
    add_files('src', %w(lib/1.rb lib/2.rb baz))
    builder = make_builder('foo', %w(lib/*.rb baz bar/*))
    FileUtils.mkdir_p(File.join(@release_dir, 'src', 'bar', 'zb'))

    s1 = builder.fingerprint

    FileUtils.mkdir_p(File.join(@release_dir, 'src', 'bar', 'zb2'))
    s2 = builder.reload.fingerprint
    s2.should_not == s1

    FileUtils.rm_rf(File.join(@release_dir, 'src', 'bar', 'zb2'))
    builder.reload.fingerprint.should == s1
  end

  it "doesn't change fingerprint when files that doesn't match glob is added" do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))
    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file('src', 'lib/a.out')
    builder.reload.fingerprint.should == s1
  end

  it 'changes fingerprint when dependencies change' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder1 = make_builder('A', %w(lib/*.rb README.*), %w(foo bar))
    s1 = builder1.fingerprint
    builder2 = make_builder('A', %w(lib/*.rb README.*), %w(bar foo))
    s2 = builder2.fingerprint
    s1.should == s2 # Order doesn't matter

    builder3 = make_builder('A', %w(lib/*.rb README.*), %w(bar foo baz))
    s3 = builder3.fingerprint
    s3.should_not == s1 # Set does matter
  end

  it 'copies files to build directory' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    builder = make_builder('bar', globs)
    builder.copy_files.should == 5

    builder2 = make_builder('bar', globs, [], builder.build_dir)

    # Also turned out to be a nice test for directory portability
    builder.fingerprint.should == builder2.fingerprint
  end

  it 'generates tarball' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    builder = make_builder('bar', %w(foo/**/* baz))
    builder.generate_tarball.should be(true)
  end

  it 'can point to either dev or a final version of a package' do
    fingerprint = 'fake-fingerprint'
    allow(Digest::SHA1).to receive(:hexdigest).and_return(fingerprint)

    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    final_versions = Bosh::Cli::VersionsIndex.new(
        File.join(@release_dir, '.final_builds', 'packages', 'bar'))
    dev_versions   = Bosh::Cli::VersionsIndex.new(
        File.join(@release_dir, '.dev_builds', 'packages', 'bar'))

    final_versions.add_version(fingerprint,
                               { 'version' => fingerprint, 'blobstore_id' => '12321' },
                               get_tmp_file_path('payload'))
    dev_versions.add_version(fingerprint,
                             { 'version' => fingerprint },
                             get_tmp_file_path('dev_payload'))

    builder = make_builder('bar', globs)

    builder.use_final_version
    builder.tarball_path.should == File.join(
        @release_dir, '.final_builds', 'packages', 'bar', "#{fingerprint}.tgz")

    builder.use_dev_version
    builder.tarball_path.should == File.join(
        @release_dir, '.dev_builds', 'packages', 'bar', "#{fingerprint}.tgz")
  end

  it 'creates a new version tarball' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder('bar', globs)

    v1_fingerprint = builder.fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz").
        should be(false)
    builder.build
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz").
        should be(true)

    builder = make_builder('bar', globs)
    builder.build

    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz").
        should be(true)
    File.exists?(@release_dir + '/.dev_builds/packages/bar/other-fingerprint.tgz').
        should be(false)

    add_file('src', 'foo/3.rb')
    builder = make_builder('bar', globs)
    builder.build

    v2_fingerprint = builder.fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v2_fingerprint}.tgz").
        should be(true)

    remove_file('src', 'foo/3.rb')
    builder = make_builder('bar', globs)
    builder.build
    builder.version.should == v1_fingerprint

    builder.fingerprint.should == v1_fingerprint

    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v2_fingerprint}.tgz").
        should be(true)

    # Now add packaging
    add_file('packages', 'bar/packaging', 'make install')
    builder = make_builder('bar', globs)
    builder.build
    v3_fingerprint = builder.fingerprint
    builder.version.should == v3_fingerprint

    # Add prepackaging
    add_file('packages', 'bar/pre_packaging', 'echo 0; exit 0')
    builder = make_builder('bar', globs)
    v4_fingerprint = builder.fingerprint

    builder.build

    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v4_fingerprint}.tgz").
        should be(true)
  end

  it 'stops if pre_packaging fails' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    builder = make_builder('bar', globs)
    add_file('packages', 'bar/pre_packaging', 'exit 1')

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::InvalidPackage,
                         "`bar' pre-packaging failed")
  end

  it 'bumps major dev version in sync with final version' do
    FileUtils.rm_rf(File.join(@release_dir, 'src_alt'))

    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder('bar', globs)
    builder.build

    builder.version.should == builder.fingerprint

    blobstore = double('blobstore')
    blobstore.should_receive(:create).and_return('object_id')
    final_builder = Bosh::Cli::PackageBuilder.new({ 'name' => 'bar',
                                                    'files' => globs },
                                                  @release_dir,
                                                  true, blobstore)
    final_builder.build
    final_builder.version.should == builder.fingerprint

    add_file('src', 'foo/foo15.rb')

    builder2 = make_builder('bar', globs)
    builder2.build
    builder2.version.should == builder2.fingerprint

    expect(builder2.version).to_not eq(builder.version)
  end

  it 'includes dotfiles in a fingerprint' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    builder.glob_matches.size.should == 4
    builder.fingerprint.should == '167bd0b339d78606cf00a8740791b54b1cf619a6'

    add_file('src', 'lib/.zb.rb')
    builder.reload

    builder.glob_matches.size.should == 5
    builder.fingerprint.should == '8e07f3d3176170c0e17baa9e2ad4e9b8b38d024a'

    remove_file('src', 'lib/.zb.rb')
    builder.reload

    builder.glob_matches.size.should == 4
    builder.fingerprint.should == '167bd0b339d78606cf00a8740791b54b1cf619a6'
  end

  it 'supports dry run' do
    FileUtils.rm_rf(File.join(@release_dir, 'src_alt'))

    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder('bar', globs)
    builder.dry_run = true
    builder.build

    builder.version.should == builder.fingerprint
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder.fingerprint}.tgz").
        should be(false)

    builder.dry_run = false
    builder.reload.build
    builder.version.should == builder.fingerprint
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder.fingerprint}.tgz").
        should be(true)

    blobstore = double('blobstore')
    blobstore.should_not_receive(:create)
    final_builder = Bosh::Cli::PackageBuilder.new(
      { 'name' => 'bar', 'files' => globs }, @release_dir, true, blobstore)
    final_builder.dry_run = true
    final_builder.build

    # Hasn't been promoted b/c of dry run
    final_builder.version.should == builder.version

    add_file('src', 'foo/foo15.rb')
    builder2 = make_builder('bar', globs)
    builder2.dry_run = true
    builder2.build
    builder2.version.should == builder2.fingerprint
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder.fingerprint}.tgz").
        should be(true)
    File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder2.fingerprint}.tgz").
        should be(false)
  end

  it 'uses blobs directory to look up files as well' do
    add_files('src', %w(lib/1.rb lib/2.rb))
    add_files('blobs', %w(lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    builder.glob_matches.size.should == 4
    builder.fingerprint.should == '167bd0b339d78606cf00a8740791b54b1cf619a6'
  end

  it "moving files to blobs directory doesn't change fingerprint" do
    add_file('src', 'README.txt', 'README contents')
    add_file('src', 'README.md', 'README contents 2')
    add_file('src', 'lib/1.rb', "puts 'Hello world'")
    add_file('src', 'lib/2.rb', "puts 'Bye world'")

    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    FileUtils.mkdir_p(File.join(@release_dir, 'blobs', 'lib'))

    FileUtils.mv(File.join(@release_dir, 'src', 'lib', '1.rb'),
                 File.join(@release_dir, 'blobs', 'lib', '1.rb'))

    s2 = builder.reload.fingerprint
    s2.should == s1
  end

  it "doesn't include the same path twice" do
    add_file('src', 'test/foo/README.txt', 'README contents')
    add_file('src', 'test/foo/NOTICE.txt', 'NOTICE contents')
    fp1 = make_builder('A', %w(test/**/*)).fingerprint

    remove_file('src', 'test/foo/NOTICE.txt')                   # src has test/foo
    add_file('blobs', 'test/foo/NOTICE.txt', 'NOTICE contents') # blobs has test/foo

    File.directory?(File.join(@release_dir, 'src', 'test', 'foo')).should be(true)

    fp2 = make_builder('A', %w(test/**/*)).fingerprint
    fp1.should == fp2
  end

  describe 'file overriding via src_alt' do
    it 'includes top-level files from src_alt instead of src' do
      add_file('src', 'file1', 'original')

      builder = make_builder('A', %w(file*))
      s1 = builder.fingerprint

      add_file('src', 'file1', 'altered')
      add_file('src_alt', 'file1', 'original')
      builder.reload.fingerprint.should == s1
    end

    it 'includes top-level files from src if not present in src_alt' do
      add_file('src', 'file1', 'original1')
      add_file('src', 'file2', 'original2')
      builder = make_builder('A', %w(file*))
      s1 = builder.fingerprint

      add_file('src', 'file1', 'altered1')
      add_file('src_alt', 'file1', 'original1')
      builder.reload.fingerprint.should == s1
    end

    it 'includes top-level-dir files from src_alt instead of src' do
      add_file('src', 'dir1/file1', 'original1')
      builder = make_builder('A', %w(dir1/*))
      s1 = builder.fingerprint

      add_file('src', 'dir1/file1', 'altered1')
      add_file('src_alt', 'dir1/file1', 'original1')
      builder.reload.fingerprint.should == s1
    end

    it 'does not include top-level-dir files from src if not present in src_alt' do
      add_file('src', 'dir1/file1', 'original1')
      builder = make_builder('A', %w(dir1/*))
      s1 = builder.fingerprint

      add_file('src', 'dir1/file2', 'new2')
      add_file('src_alt', 'dir1/file1', 'original1')
      builder.reload.fingerprint.should == s1
    end

    it "checks if glob top-level-dir is present in src_alt but doesn't match" do
      add_file('src', 'dir1/file1', 'original1')
      FileUtils.mkdir(File.join(@release_dir, 'src_alt', 'dir1'))

      builder = make_builder('A', %w(dir1/*))

      lambda {
        builder.fingerprint
      }.should raise_error(
        "Package `A' has a glob that doesn't match " +
        "in `src_alt' but matches in `src'. However " +
        "`src_alt/dir1' exists, so this might be an error."
       )
    end

    it 'raises an error if glob does not match any files in src or src_alt' do
      builder = make_builder('A', %w(dir1/*))

      lambda {
        builder.reload.fingerprint
      }.should raise_error("Package `A' has a glob that resolves to an empty file list: dir1/*")
    end

    it 'prevents building final version with src_alt' do
      lambda {
        Bosh::Cli::PackageBuilder.new({
          'name' => 'bar',
          'files' => 'foo/**/*'
        }, @release_dir, true, double('blobstore'))
      }.should raise_error(/Please remove `src_alt' first/)
    end
  end
end
