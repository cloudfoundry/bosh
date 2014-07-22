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

  def make_builder(name, files, dependencies = [], sources_dir = nil, excluded_files=[])
    blobstore = double('blobstore')
    spec = {
      'name' => name,
      'files' => files,
      'dependencies' => dependencies,
      'excluded_files' => excluded_files,
    }

    Bosh::Cli::PackageBuilder.new(spec, @release_dir,
                                  false, blobstore, sources_dir)
  end

  it 'whines on missing name' do
    expect {
      make_builder(' ', [])
    }.to raise_error(Bosh::Cli::InvalidPackage, 'Package name is missing')
  end

  it 'whines on funny characters in name' do
    expect {
      make_builder('@#!', [])
    }.to raise_error(Bosh::Cli::InvalidPackage,
      'Package name should be a valid BOSH identifier')
  end

  it 'whines on empty files' do
    expect {
      make_builder('aa', [])
    }.to raise_error(Bosh::Cli::InvalidPackage, "Package 'aa' doesn't include any files")
  end

  it 'whines on metadata file having the same name as one of package files' do
    expect {
      builder = make_builder('aa', %w(*.rb packaging))

      add_files('src', %w(1.rb packaging))

      expect(builder.glob_matches.size).to eql(2)
      add_file('packages', 'aa/packaging', 'make install')

      builder.copy_files
    }.to raise_error(Bosh::Cli::InvalidPackage,
                         "Package 'aa' has 'packaging' file which " +
                           'conflicts with BOSH packaging')
  end

  it 'whines on globs not yielding any file names' do
    add_files('src',  %w(lib/1.rb lib/2.rb baz))
    builder = make_builder('foo', %w(lib/*.rb baz bar))

    expect {
      builder.build
    }.to raise_error(Bosh::Cli::InvalidPackage,
                         "Package `foo' has a glob that resolves " +
                           'to an empty file list: bar')
  end

  it 'has no way to calculate checksum for not yet generated package' do
    expect {
      builder = make_builder('aa', %w(*.rb packaging))
      add_files('src', %w(1.rb packaging))
      builder.checksum
    }.to raise_error(RuntimeError,
                         'cannot read checksum for not yet ' +
                           'generated package/job')
  end

  it 'has a checksum for a generated package' do
    builder = make_builder('aa', %w(*.rb))
    add_files('src', %w(1.rb 2.rb))
    builder.build
    expect(builder.checksum).to match(/[0-9a-f]+/)
  end

  it 'is created with name and globs' do
    builder = make_builder('aa', %w(1 */*))
    expect(builder.name).to eql('aa')
    expect(builder.globs).to eql(%w(1 */*))
  end

  it 'resolves globs and generates fingerprint' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    expect(builder.glob_matches.size).to eql(4)
    expect(builder.fingerprint).to eql('167bd0b339d78606cf00a8740791b54b1cf619a6')
  end

  it 'has stable fingerprint' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))
    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    expect(builder.reload.fingerprint).to eql(s1)
  end

  it 'changes fingerprint when new file that matches glob is added' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint
    add_files('src', %w(lib/3.rb))
    expect(builder.reload.fingerprint).to_not eql(s1)

    remove_files('src', %w(lib/3.rb))
    expect(builder.reload.fingerprint).to eql(s1)
  end

  it 'changes fingerprint when one of the matched files changes' do
    add_files('src', %w(lib/2.rb lib/README.txt README.2 README.md))
    add_file('src', 'lib/1.rb', '1')

    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file('src', 'lib/1.rb', '2')
    expect(builder.reload.fingerprint).to_not eql(s1)

    add_file('src', 'lib/1.rb', '1')
    expect(builder.reload.fingerprint).to eql(s1)
  end

  it 'changes fingerprint when empty directory added/removed' do
    add_files('src', %w(lib/1.rb lib/2.rb baz))
    builder = make_builder('foo', %w(lib/*.rb baz bar/*))
    FileUtils.mkdir_p(File.join(@release_dir, 'src', 'bar', 'zb'))

    s1 = builder.fingerprint

    FileUtils.mkdir_p(File.join(@release_dir, 'src', 'bar', 'zb2'))
    s2 = builder.reload.fingerprint
    expect(s2).to_not eql(s1)

    FileUtils.rm_rf(File.join(@release_dir, 'src', 'bar', 'zb2'))
    expect(builder.reload.fingerprint).to eql(s1)
  end

  it "doesn't change fingerprint when files that doesn't match glob is added" do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))
    builder = make_builder('A', %w(lib/*.rb README.*))
    s1 = builder.fingerprint

    add_file('src', 'lib/a.out')
    expect(builder.reload.fingerprint).to eql(s1)
  end

  it 'changes fingerprint when dependencies change' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder1 = make_builder('A', %w(lib/*.rb README.*), %w(foo bar))
    s1 = builder1.fingerprint
    builder2 = make_builder('A', %w(lib/*.rb README.*), %w(bar foo))
    s2 = builder2.fingerprint
    expect(s1).to eql(s2) # Order doesn't matter

    builder3 = make_builder('A', %w(lib/*.rb README.*), %w(bar foo baz))
    s3 = builder3.fingerprint
    expect(s3).to_not eql(s1) # Set does matter
  end

  it 'copies files to build directory' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    builder = make_builder('bar', globs)
    expect(builder.copy_files).to eql(5)

    builder2 = make_builder('bar', globs, [], builder.build_dir)

    # Also turned out to be a nice test for directory portability
    expect(builder.fingerprint).to eql(builder2.fingerprint)
  end

  it 'excludes excluded_files from build directory' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README foo/.git baz))
    add_files('blobs', %w(bar/bar.tgz bar/fake.tgz))
    globs = %w(foo/**/* baz bar/**)
    excluded_globs = %w(foo/.git bar/fake.tgz)

    builder = make_builder('bar', globs, [], nil, excluded_globs)

    expect(builder.copy_files).to eq(6)
    excluded_file = File.join(builder.build_dir, 'foo', '.git')
    expect(File).to_not exist(excluded_file)

    excluded_blob_file = File.join(builder.build_dir, 'blobs', 'bar.tgz')
    expect(File).to_not exist(excluded_blob_file)
  end

  it 'generates tarball' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    builder = make_builder('bar', %w(foo/**/* baz))
    expect(builder.generate_tarball).to eql(true)
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
    expect(builder.tarball_path).to eql(File.join(
        @release_dir, '.final_builds', 'packages', 'bar', "#{fingerprint}.tgz"))

    builder.use_dev_version
    expect(builder.tarball_path).to eql(File.join(
        @release_dir, '.dev_builds', 'packages', 'bar', "#{fingerprint}.tgz"))
  end

  it 'creates a new version tarball' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder('bar', globs)

    v1_fingerprint = builder.fingerprint

    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz")).to eql(false)
    builder.build
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz")).to eql(true)

    builder = make_builder('bar', globs)
    builder.build

    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz")).to eql(true)
    expect(File.exists?(@release_dir + '/.dev_builds/packages/bar/other-fingerprint.tgz')).to eql(false)

    add_file('src', 'foo/3.rb')
    builder = make_builder('bar', globs)
    builder.build

    v2_fingerprint = builder.fingerprint

    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz")).to eql(true)
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v2_fingerprint}.tgz")).to eql(true)

    remove_file('src', 'foo/3.rb')
    builder = make_builder('bar', globs)
    builder.build
    expect(builder.version).to eql(v1_fingerprint)

    expect(builder.fingerprint).to eql(v1_fingerprint)

    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v1_fingerprint}.tgz")).to eql(true)
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v2_fingerprint}.tgz")).to eql(true)

    # Now add packaging
    add_file('packages', 'bar/packaging', 'make install')
    builder = make_builder('bar', globs)
    builder.build
    v3_fingerprint = builder.fingerprint
    expect(builder.version).to eql(v3_fingerprint)

    # Add prepackaging
    add_file('packages', 'bar/pre_packaging', 'echo 0; exit 0')
    builder = make_builder('bar', globs)
    v4_fingerprint = builder.fingerprint

    builder.build

    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{v4_fingerprint}.tgz")).to eql(true)
  end

  it 'stops if pre_packaging fails' do
    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)

    builder = make_builder('bar', globs)
    add_file('packages', 'bar/pre_packaging', 'exit 1')

    expect {
      builder.build
    }.to raise_error(Bosh::Cli::InvalidPackage,
                         "`bar' pre-packaging failed")
  end

  it 'bumps major dev version in sync with final version' do
    FileUtils.rm_rf(File.join(@release_dir, 'src_alt'))

    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder('bar', globs)
    builder.build

    expect(builder.version).to eql(builder.fingerprint)

    blobstore = double('blobstore')
    expect(blobstore).to receive(:create).and_return('object_id')
    final_builder = Bosh::Cli::PackageBuilder.new({ 'name' => 'bar',
                                                    'files' => globs },
                                                  @release_dir,
                                                  true, blobstore)
    final_builder.build
    expect(final_builder.version).to eql(builder.fingerprint)

    add_file('src', 'foo/foo15.rb')

    builder2 = make_builder('bar', globs)
    builder2.build
    expect(builder2.version).to eql(builder2.fingerprint)

    expect(builder2.version).to_not eq(builder.version)
  end

  it 'includes dotfiles in a fingerprint' do
    add_files('src', %w(lib/1.rb lib/2.rb lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    expect(builder.glob_matches.size).to eql(4)
    expect(builder.fingerprint).to eql('167bd0b339d78606cf00a8740791b54b1cf619a6')

    add_file('src', 'lib/.zb.rb')
    builder.reload

    expect(builder.glob_matches.size).to eql(5)
    expect(builder.fingerprint).to eql('8e07f3d3176170c0e17baa9e2ad4e9b8b38d024a')

    remove_file('src', 'lib/.zb.rb')
    builder.reload

    expect(builder.glob_matches.size).to eql(4)
    expect(builder.fingerprint).to eql('167bd0b339d78606cf00a8740791b54b1cf619a6')
  end

  it 'supports dry run' do
    FileUtils.rm_rf(File.join(@release_dir, 'src_alt'))

    add_files('src', %w(foo/foo.rb foo/lib/1.rb foo/lib/2.rb foo/README baz))
    globs = %w(foo/**/* baz)
    builder = make_builder('bar', globs)
    builder.dry_run = true
    builder.build

    expect(builder.version).to eql(builder.fingerprint)
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder.fingerprint}.tgz")).to eql(false)

    builder.dry_run = false
    builder.reload.build
    expect(builder.version).to eql(builder.fingerprint)
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder.fingerprint}.tgz")).to eql(true)

    blobstore = double('blobstore')
    expect(blobstore).to_not receive(:create)
    final_builder = Bosh::Cli::PackageBuilder.new(
      { 'name' => 'bar', 'files' => globs }, @release_dir, true, blobstore)
    final_builder.dry_run = true
    final_builder.build

    # Hasn't been promoted b/c of dry run
    expect(final_builder.version).to eql(builder.version)

    add_file('src', 'foo/foo15.rb')
    builder2 = make_builder('bar', globs)
    builder2.dry_run = true
    builder2.build
    expect(builder2.version).to eql(builder2.fingerprint)
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder.fingerprint}.tgz")).to eql(true)
    expect(File.exists?(@release_dir + "/.dev_builds/packages/bar/#{builder2.fingerprint}.tgz")).to eql(false)
  end

  it 'uses blobs directory to look up files as well' do
    add_files('src', %w(lib/1.rb lib/2.rb))
    add_files('blobs', %w(lib/README.txt README.2 README.md))

    builder = make_builder('A', %w(lib/*.rb README.*))
    expect(builder.glob_matches.size).to eql(4)
    expect(builder.fingerprint).to eql('167bd0b339d78606cf00a8740791b54b1cf619a6')
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
    expect(s2).to eql(s1)
  end

  it "doesn't include the same path twice" do
    add_file('src', 'test/foo/README.txt', 'README contents')
    add_file('src', 'test/foo/NOTICE.txt', 'NOTICE contents')
    fp1 = make_builder('A', %w(test/**/*)).fingerprint

    remove_file('src', 'test/foo/NOTICE.txt')                   # src has test/foo
    add_file('blobs', 'test/foo/NOTICE.txt', 'NOTICE contents') # blobs has test/foo

    expect(File.directory?(File.join(@release_dir, 'src', 'test', 'foo'))).to eql(true)

    fp2 = make_builder('A', %w(test/**/*)).fingerprint
    expect(fp1).to eql(fp2)
  end

  describe 'file overriding via src_alt' do
    it 'includes top-level files from src_alt instead of src' do
      add_file('src', 'file1', 'original')

      builder = make_builder('A', %w(file*))
      s1 = builder.fingerprint

      add_file('src', 'file1', 'altered')
      add_file('src_alt', 'file1', 'original')
      expect(builder.reload.fingerprint).to eql(s1)
    end

    it 'includes top-level files from src if not present in src_alt' do
      add_file('src', 'file1', 'original1')
      add_file('src', 'file2', 'original2')
      builder = make_builder('A', %w(file*))
      s1 = builder.fingerprint

      add_file('src', 'file1', 'altered1')
      add_file('src_alt', 'file1', 'original1')
      expect(builder.reload.fingerprint).to eql(s1)
    end

    it 'includes top-level-dir files from src_alt instead of src' do
      add_file('src', 'dir1/file1', 'original1')
      builder = make_builder('A', %w(dir1/*))
      s1 = builder.fingerprint

      add_file('src', 'dir1/file1', 'altered1')
      add_file('src_alt', 'dir1/file1', 'original1')
      expect(builder.reload.fingerprint).to eql(s1)
    end

    it 'does not include top-level-dir files from src if not present in src_alt' do
      add_file('src', 'dir1/file1', 'original1')
      builder = make_builder('A', %w(dir1/*))
      s1 = builder.fingerprint

      add_file('src', 'dir1/file2', 'new2')
      add_file('src_alt', 'dir1/file1', 'original1')
      expect(builder.reload.fingerprint).to eql(s1)
    end

    it "checks if glob top-level-dir is present in src_alt but doesn't match" do
      add_file('src', 'dir1/file1', 'original1')
      FileUtils.mkdir(File.join(@release_dir, 'src_alt', 'dir1'))

      builder = make_builder('A', %w(dir1/*))

      expect {
        builder.fingerprint
      }.to raise_error(
        "Package `A' has a glob that doesn't match " +
        "in `src_alt' but matches in `src'. However " +
        "`src_alt/dir1' exists, so this might be an error."
       )
    end

    it 'raises an error if glob does not match any files in src or src_alt' do
      builder = make_builder('A', %w(dir1/*))

      expect {
        builder.reload.fingerprint
      }.to raise_error("Package `A' has a glob that resolves to an empty file list: dir1/*")
    end

    it 'prevents building final version with src_alt' do
      expect {
        Bosh::Cli::PackageBuilder.new({
          'name' => 'bar',
          'files' => 'foo/**/*'
        }, @release_dir, true, double('blobstore'))
      }.to raise_error(/Please remove `src_alt' first/)
    end
  end
end
