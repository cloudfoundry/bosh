require 'spec_helper'

describe Bosh::Cli::PackageBuilder, 'dev build' do
  subject(:builder) { make_builder }

  let(:release_dir) { Support::FileHelpers::ReleaseDirectory.new }
  let(:basedir) { nil } # meh!
  let(:package_name) { 'pkg' }
  let(:package_file_patterns) { ['*.rb'] }
  let(:package_deps) { ['foo', 'bar'] }
  let(:excluded_file_patterns) { [] }
  let(:final) { false }
  let(:blobstore) { double('blobstore') }

  before do
    release_dir.add_dir('blobs')
    release_dir.add_dir('src')
  end

  after { release_dir.cleanup }

  def make_builder
    spec = {
      'name' => package_name,
      'files' => package_file_patterns,
      'dependencies' => package_deps,
      'excluded_files' => excluded_file_patterns,
    }

    Bosh::Cli::PackageBuilder.new(spec, release_dir.path, final, blobstore)
  end

  describe 'initialization of a new builder' do
    it 'sets the builder name' do
      expect(builder.name).to eql(package_name)
    end

    it 'sets the builder name' do
      expect(builder.globs).to eql(package_file_patterns)
    end

    context 'when name is missing' do
      let(:package_name) { ' ' }

      it 'raises' do
        expect { make_builder }.to raise_error(Bosh::Cli::InvalidPackage, 'Package name is missing')
      end
    end

    context 'when name has funny characters' do
      let(:package_name) { '@#!' }

      it 'raises' do
        expect { make_builder }.to raise_error(Bosh::Cli::InvalidPackage, 'Package name should be a valid BOSH identifier')
      end
    end

    context 'when no package files are specified' do
      let(:package_file_patterns) { [] }

      it 'raises' do
        expect { make_builder }.to raise_error(Bosh::Cli::InvalidPackage, "Package '#{package_name}' doesn't include any files")
      end
    end
  end

  describe 'generating the package checksum' do
    before { release_dir.add_file('src', '1.rb') }

    it 'has a checksum for a generated package' do
      builder.build
      expect(builder.checksum).to match(/^[0-9a-f]{40}$/)
    end

    it 'does not attempt to calculate checksum for as yet ungenerated package' do
      expect {
        builder.checksum
      }.to raise_error(RuntimeError, 'cannot read checksum for not yet generated package')
    end
  end

  describe 'building the package' do
    let(:package_file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }

    before do
      matched_files.each { |f| release_dir.add_file('src', f, "contents of #{f}") }
      release_dir.add_file('src', 'unmatched.txt')
    end

    it 'copies files to build directory' do
      builder.build

      expect(directory_listing(builder.build_dir)).to contain_exactly(*matched_files)
      matched_files.each do |f|
        expect(File.read(File.join(builder.build_dir, f))).to eq("contents of #{f}")
      end
    end

    it 'generates a tarball' do
      builder.build
      expect(release_dir).to have_file(".dev_builds/packages/#{package_name}/#{builder.fingerprint}.tgz")
    end

    context 'when in dry run mode' do
      before { builder.dry_run = true }

      it 'writes no tarballs' do
        expect { builder.build }.not_to change { directory_listing(release_dir.path) }
      end
    end

    context 'when building final release' do
      let(:storage_dir) { ".final_builds/packages/#{package_name}" }
      let(:final) { true }

      before { allow(blobstore).to receive(:create).and_return('object_id') }

      it 'generates a tarball' do
        builder.build
        expect(release_dir).to have_file("#{storage_dir}/#{builder.fingerprint}.tgz")
        tarball_file = release_dir.join("#{storage_dir}/#{builder.fingerprint}.tgz")
        expect(`tar tfz #{tarball_file}`.split(/\n/)).to contain_exactly(
            "./", "./README.2", "./README.md", "./lib/", "./lib/1.rb", "./lib/2.rb")
      end

      context 'with empty directories are matched' do
        let(:package_file_patterns) { ['lib/*.rb', 'README.*', 'include_me'] }
        before { release_dir.add_dir('src/include_me')}

        it 'generates a tarball which includes them' do
          builder.build
          expect(release_dir).to have_file("#{storage_dir}/#{builder.fingerprint}.tgz")
          tarball_file = release_dir.join("#{storage_dir}/#{builder.fingerprint}.tgz")
          expect(`tar tfz #{tarball_file}`.split(/\n/)).to contain_exactly(
              "./", "./README.2", "./README.md", "./include_me/", "./lib/", "./lib/1.rb", "./lib/2.rb")
        end
      end

      context 'when a src_alt exists' do
        before { release_dir.add_dir('src_alt') }

        it 'prevents building final version' do
          expect {
            Bosh::Cli::PackageBuilder.new({
                'name' => 'bar',
                'files' => 'foo/**/*'
              }, release_dir.path, true, blobstore)
          }.to raise_error(/Please remove 'src_alt' first/)
        end
      end
    end

    context 'when metadata file has the same name as one of the package files' do
      let(:package_file_patterns) { ['*.rb', 'packaging'] }

      before do
        release_dir.add_files('src', ['1.rb', 'packaging'])
        release_dir.add_file('packages', "#{package_name}/packaging")
      end

      it 'raises' do
        expect {
          builder.build
        }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{package_name}' has 'packaging' file which conflicts with BOSH packaging")
      end
    end

    context 'when a glob matches no files' do
      let(:package_file_patterns) { ['lib/*.rb', 'baz', 'bar'] }

      before do
        release_dir.add_files('src', ['lib/1.rb', 'lib/2.rb', 'baz'])
      end

      it 'raises' do
        expect {
          builder.build
        }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{package_name}' has a glob that resolves to an empty file list: bar")
      end
    end

    context 'when the package contains blobs' do
      let(:package_file_patterns) { ['lib/*.rb', 'README.*', '**/*.tgz'] }
      let(:matched_blobs) { ['matched.tgz'] }

      before { release_dir.add_files('blobs', matched_blobs) }

      it 'includes the blobs in the build' do
        builder.build
        expect(directory_listing(builder.build_dir)).to contain_exactly(*(matched_files + matched_blobs))
      end

      context 'when blobs have the same name as files in src' do
        before do
          release_dir.add_file('src', 'README.txt', 'README from src')
          release_dir.add_file('blobs', 'README.txt', 'README from blobs')
        end

        it 'picks the content from src' do
          builder.build
          expect(File.read(File.join(builder.build_dir, 'README.txt'))).to eq('README from src')
        end
      end
    end

    context 'when the package contains a src_alt dir' do
      before { release_dir.add_dir('src_alt') }

      it 'includes top-level files from src_alt instead of src' do
        release_dir.add_file('src_alt', 'README.md', 'README.md from src_alt')
        builder.build
        expect(File.read(File.join(builder.build_dir, 'README.md'))).to eq('README.md from src_alt')
      end

      context 'when src_alt contains a top-level dir matching a dir in src' do
        it 'the contents from src_alt are used and the contents from src are ignored' do
          release_dir.add_file('src_alt', 'lib/2.rb', 'lib/2.rb from src_alt')
          release_dir.add_file('src_alt', 'lib/3.rb', 'lib/3.rb from src_alt')
          builder.build
          expect(directory_listing(builder.build_dir)).to contain_exactly('lib/2.rb', 'lib/3.rb', 'README.2', 'README.md')
          expect(File.read(File.join(builder.build_dir, 'lib/2.rb'))).to eq('lib/2.rb from src_alt')
        end
      end

      it "checks if glob top-level-dir is present in src_alt but doesn't match" do
        release_dir.add_dir('src_alt/lib')

        expect {
          builder.build
        }.to raise_error("Package '#{package_name}' has a glob that doesn't match in 'src_alt' but matches in 'src'. However 'src_alt/lib' exists, so this might be an error.")
      end

      context 'when a package file pattern does not match any files in src or src_alt' do
        let(:package_file_patterns) { ['lib2/*'] }

        it 'raises an error' do
          expect {
            builder.build
          }.to raise_error("Package '#{package_name}' has a glob that resolves to an empty file list: lib2/*")
        end
      end
    end

    context 'when specifying files to exclude' do
      let(:package_file_patterns) { ['**/*'] }
      let(:matched_blobs) { ['matched.tgz'] }
      let(:excluded_blobs) { ['excluded.tgz'] }
      let(:excluded_src) { ['.git'] }
      let(:excluded_file_patterns) { ['.git', 'excluded.tgz', 'unmatched.txt'] }

      before do
        release_dir.add_files('src', matched_files + excluded_src)
        release_dir.add_files('blobs', matched_blobs + excluded_blobs)
      end

      it 'the exclusions are not found in the build directory' do
        builder.build
        expect(directory_listing(builder.build_dir)).to contain_exactly(*(matched_files + matched_blobs))
      end
    end
  end

  describe 'the generated package fingerprint' do
    let(:package_file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }
    let(:reference_fingerprint) { 'f0b1b81bd6b8093f2627eaa13952a1aab8b125d1' }

    before { matched_files.each { |f| release_dir.add_file('src', f, "contents of #{f}") } }

    it 'is used as the version' do
      builder.build
      expect(builder.version).to eq(reference_fingerprint)
    end

    it 'resolves globs to matched files' do
      expect(builder.glob_matches.map(&:path)).to contain_exactly(*matched_files)
    end

    it 'is based on the matched files, ignoring unmatched files' do
      release_dir.add_file('src', 'an-unmatched-file.txt')
      expect(builder.fingerprint).to eq(reference_fingerprint)
    end

    it 'varies with the set of matched files' do
      release_dir.add_file('src', 'lib/a_matched_file.rb')
      expect(builder.fingerprint).to_not eq(reference_fingerprint)
    end

    it 'varies with the content of matched files' do
      release_dir.add_file('src', 'lib/1.rb', 'varied contents')
      expect(builder.fingerprint).to_not eq(reference_fingerprint)
    end

    context 'when a file pattern matches empty directories' do
      let(:package_file_patterns) { ['lib/*.rb', 'README.*', 'tmp'] }

      it 'varies' do
        release_dir.add_dir('src/tmp')
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file pattern matches a dotfile' do
      before { release_dir.add_file('src', 'lib/.zb.rb') }

      it 'the dotfile is included in the fingerprint' do
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary in order' do
      let(:package_deps) { ['bar', 'foo'] }

      it 'does not vary' do
        expect(builder.fingerprint).to eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary' do
      let(:package_deps) { ['foo', 'bar', 'baz'] }

      it 'varies' do
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when blobs are present' do
      let(:package_file_patterns) { ['lib/*.rb', 'README.*', '*.tgz'] }
      before { release_dir.add_file('blobs', 'matched.tgz') }

      it 'varies' do
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file comes from blobs instead of src' do
      before { FileUtils.mv(release_dir.join('src', 'README.md'), release_dir.join('blobs', 'README.md')) }

      it 'does not vary' do
        expect(builder.fingerprint).to eq(reference_fingerprint)
      end
    end

    context 'when the package contains a src_alt dir' do
      it 'includes top-level files from src_alt instead of src' do
        release_dir.add_file('src_alt', 'README.md', 'README.md from src_alt')
        builder.build
        expect(builder.fingerprint).not_to eq(reference_fingerprint)
      end
    end
  end

  describe 'pre_packaging script' do
    let(:temp_file) { Tempfile.new('pre_packaging.out') }
    before { release_dir.add_file('src', '2.rb') }
    after { temp_file.unlink }

    it 'is executed as part of the build' do
      release_dir.add_file('packages', "#{package_name}/pre_packaging",
        "echo 'Luke I am your father.' > #{temp_file.path}; exit 0")

      builder.build
      expect(temp_file.read).to eq("Luke I am your father.\n")
    end

    context 'if the script exits with non-zero' do
      it 'causes the builder to raise' do
        release_dir.add_file('packages', "#{package_name}/pre_packaging", 'exit 1')

        expect {
          builder.build
        }.to raise_error(Bosh::Cli::InvalidPackage, "'#{package_name}' pre-packaging failed")
      end
    end
  end

  describe 'using pre-built versions' do
    let(:package_file_patterns) { ['foo/**/*', 'baz'] }
    let(:fingerprint) { 'fake-fingerprint' }
    let(:final_storage_dir) { ".final_builds/packages/#{package_name}" }
    let(:dev_storage_dir) { ".dev_builds/packages/#{package_name}" }

    before do
      allow(Digest::SHA1).to receive(:hexdigest).and_return(fingerprint)
      release_dir.add_files('src', ['foo/foo.rb', 'foo/lib/1.rb', 'foo/lib/2.rb', 'foo/README', 'baz'])
    end

    context 'when a final version is available locally' do
      before { release_dir.add_version(fingerprint, final_storage_dir, 'payload', {'version' => fingerprint, 'blobstore_id' => '12321'}) }

      it 'should use the final version' do
        builder.build
        expect(builder.tarball_path).to eq(release_dir.join('.final_builds', 'packages', package_name, "#{fingerprint}.tgz"))
      end
    end

    context 'when a dev version is available locally' do
      before { release_dir.add_version(fingerprint, dev_storage_dir, 'dev_payload', {'version' => fingerprint}) }

      it 'should use the final version' do
        builder.build
        expect(builder.tarball_path).to eq(release_dir.join('.dev_builds', 'packages', package_name, "#{fingerprint}.tgz"))
      end

      context 'and a final version is also available locally' do
        before { release_dir.add_version(fingerprint, final_storage_dir, 'payload', {'version' => fingerprint, 'blobstore_id' => '12321'}) }

        it 'should use the final version' do
          builder.build
          expect(builder.tarball_path).to eq(release_dir.join('.final_builds', 'packages', package_name, "#{fingerprint}.tgz"))
        end
      end
    end

    context 'when a final or dev version is not available locally' do
      it 'generates a tarball and saves it as a dev build' do
        builder.build
        expect(builder.tarball_path).to eq(release_dir.join('.dev_builds', 'packages', package_name, "#{fingerprint}.tgz"))
      end
    end
  end
end
