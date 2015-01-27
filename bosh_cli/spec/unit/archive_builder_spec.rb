require 'spec_helper'

describe Bosh::Cli::ArchiveBuilder, 'dev build' do
  subject(:builder) { Bosh::Cli::ArchiveBuilder.new(resource, archive_dir, blobstore) }

  let(:resource) do
    spec = {
      'name' => resource_name,
      'files' => resource_file_patterns,
      'dependencies' => resource_deps,
      'excluded_files' => excluded_file_patterns,
    }

    Bosh::Cli::Resources::Package.new(spec, release_source.path, final, blobstore)
  end

  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }
  let(:archive_dir) { release_source.path }
  let(:basedir) { nil } # meh!
  let(:tmp_dirs) { [] }

  let(:resource_name) { 'pkg' }
  let(:resource_file_patterns) { ['*.rb'] }
  let(:resource_deps) { ['foo', 'bar'] }
  let(:excluded_file_patterns) { [] }
  let(:final) { false }
  let(:blobstore) { double('blobstore') }

  before do
    release_source.add_dir('blobs')
    release_source.add_dir('src')
  end

  after do
    release_source.cleanup
    tmp_dirs.each { |dir| FileUtils.rm_rf(dir) }
  end

  def open_archive(file)
    tmp_dirs << tmp_dir = Dir.mktmpdir
    Dir.chdir(tmp_dir) { `tar xfz #{file}` }
    tmp_dir
  end

  describe 'generating the resource checksum' do
    before { release_source.add_file('src', '1.rb') }

    it 'has a checksum for a generated resource' do
      builder.build
      expect(builder.checksum).to match(/^[0-9a-f]{40}$/)
    end

    it 'does not attempt to calculate checksum for as yet ungenerated resource' do
      expect {
        builder.checksum
      }.to raise_error(RuntimeError, 'cannot read checksum for not yet generated package')
    end
  end

  describe 'building the resource' do
    let(:resource_file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }

    before do
      matched_files.each { |f| release_source.add_file('src', f, "contents of #{f}") }
      release_source.add_file('src', 'unmatched.txt')
    end

    it 'copies the resource files to build directory' do
      builder.build

      explosion = open_archive(builder.tarball_path)
      expect(directory_listing(explosion)).to contain_exactly(*matched_files)

      resource.files.each do |tuple|
        path = tuple[1]
        expect(File.read(File.join(explosion, path))).to eq("contents of #{path}")
      end
    end

    context 'when the resource is a Package' do
      it 'generates a tarball' do
        builder.build
        expect(release_source).to have_file(".dev_builds/packages/#{resource_name}/#{builder.fingerprint}.tgz")
      end
    end

    xcontext 'when the resource is a Job' do
      let(:resource_name) { 'job-name' }
      let(:packages) { ['foo', 'bar'] }
      let(:templates) { ['a.conf', 'b.yml'] }
      let(:built_packages) { ['foo', 'bar'] }

      let(:resource) do
        spec = {
          'name' => resource_name,
          'packages' => packages,
          'templates' => templates.inject({}) { |h, e| h[e] = e; h }
        }

        Bosh::Cli::Resources::Job.new(spec, release_source.path,
          final, blobstore, built_packages)
      end

      before do
        add_templates(resource_name, *templates)
        add_monit(resource_name)
        add_job_file(resource_name, 'spec')
      end

      def add_monit(name, file = 'monit')
        add_job_file(name, file)
      end

      def add_job_file(name, file, contents = nil)
        release_source.add_file("jobs/#{name}", file, contents)
      end

      def add_templates(name, *files)
        job_template_path = release_source.join('jobs', name, 'templates')
        FileUtils.mkdir_p(job_template_path)

        files.each do |file|
          add_job_file(name, "templates/#{file}")
        end
      end

      it 'generates a tarball' do
        builder.build
        expect(release_source).to have_file(".dev_builds/jobs/#{resource_name}/#{builder.fingerprint}.tgz")
      end
    end

    context 'when in dry run mode' do
      before { builder.dry_run = true }

      it 'writes no tarballs' do
        expect { builder.build }.not_to change { directory_listing(release_source.path) }
      end

      it 'does not upload the tarball' do
        expect(blobstore).to_not receive(:create)
        builder.build
      end

      context 'when final' do
        let(:final) {true}

        it 'does not upload the tarball' do
          expect(blobstore).to_not receive(:create)
          builder.build
        end
      end
    end

    context 'when building final release' do
      let(:storage_dir) { ".final_builds/packages/#{resource_name}" }
      let(:final) { true }

      before { allow(blobstore).to receive(:create).and_return('object_id') }

      it 'generates a tarball' do
        builder.build
        tarball_file = release_source.join("#{storage_dir}/#{builder.fingerprint}.tgz")
        explosion = open_archive(tarball_file)

        expect(directory_listing(explosion)).to contain_exactly("README.2", "README.md", "lib/1.rb", "lib/2.rb")
      end

      it 'uploads the tarball' do
        expect(blobstore).to receive(:create)
        builder.build
      end

      context 'with empty directories are matched' do
        let(:resource_file_patterns) { ['lib/*.rb', 'README.*', 'include_me'] }
        before { release_source.add_dir('src/include_me')}

        it 'generates a tarball which includes them' do
          builder.build
          tarball_file = release_source.join("#{storage_dir}/#{builder.fingerprint}.tgz")
          explosion = open_archive(tarball_file)

          expect(directory_listing(explosion, true)).to contain_exactly("README.2", "README.md", "include_me", "lib", "lib/1.rb", "lib/2.rb")
        end
      end

      context 'when a src_alt exists' do
        before { release_source.add_dir('src_alt') }

        it 'prevents building final version' do
          expect {
            Bosh::Cli::Resources::Package.new({
                'name' => 'bar',
                'files' => 'foo/**/*'
              }, release_source.path, true, blobstore)
          }.to raise_error(/Please remove 'src_alt' first/)
        end
      end
    end

    context 'when metadata file has the same name as one of the resource files' do
      let(:resource_file_patterns) { ['*.rb', 'packaging'] }

      before do
        release_source.add_files('src', ['1.rb', 'packaging'])
        release_source.add_file('packages', "#{resource_name}/packaging")
      end

      it 'raises' do
        expect {
          builder.build
        }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{resource_name}' has 'packaging' file which conflicts with BOSH packaging")
      end
    end

    context 'when a glob matches no files' do
      let(:resource_file_patterns) { ['lib/*.rb', 'baz', 'bar'] }

      before do
        release_source.add_files('src', ['lib/1.rb', 'lib/2.rb', 'baz'])
      end

      it 'raises' do
        expect {
          builder.build
        }.to raise_error(Bosh::Cli::InvalidPackage,
            "Package '#{resource_name}' has a glob that resolves to an empty file list: bar")
      end
    end

    context 'when the resource contains blobs' do
      let(:resource_file_patterns) { ['lib/*.rb', 'README.*', '**/*.tgz'] }
      let(:matched_blobs) { ['matched.tgz'] }

      before { release_source.add_files('blobs', matched_blobs) }

      it 'includes the blobs in the build' do
        builder.build

        explosion = open_archive(builder.tarball_path)
        expect(directory_listing(explosion)).to contain_exactly(*(matched_files + matched_blobs))
      end

      context 'when blobs have the same name as files in src' do
        before do
          release_source.add_file('src', 'README.txt', 'README from src')
          release_source.add_file('blobs', 'README.txt', 'README from blobs')
        end

        it 'picks the content from src' do
          builder.build

          explosion = open_archive(builder.tarball_path)
          expect(File.read(File.join(explosion, 'README.txt'))).to eq('README from src')
        end
      end
    end

    context 'when the resource contains a src_alt dir' do
      before { release_source.add_dir('src_alt') }

      it 'includes top-level files from src_alt instead of src' do
        release_source.add_file('src_alt', 'README.md', 'README.md from src_alt')
        builder.build

        explosion = open_archive(builder.tarball_path)
        expect(File.read(File.join(explosion, 'README.md'))).to eq('README.md from src_alt')
      end

      context 'when src_alt contains a top-level dir matching a dir in src' do
        it 'the contents from src_alt are used and the contents from src are ignored' do
          release_source.add_file('src_alt', 'lib/2.rb', 'lib/2.rb from src_alt')
          release_source.add_file('src_alt', 'lib/3.rb', 'lib/3.rb from src_alt')
          builder.build

          explosion = open_archive(builder.tarball_path)
          expect(directory_listing(explosion)).to contain_exactly('lib/2.rb', 'lib/3.rb', 'README.2', 'README.md')
          expect(File.read(File.join(explosion, 'lib/2.rb'))).to eq('lib/2.rb from src_alt')
        end
      end

      it "checks if glob top-level-dir is present in src_alt but doesn't match" do
        release_source.add_dir('src_alt/lib')

        expect {
          builder.build
        }.to raise_error("Package '#{resource_name}' has a glob that doesn't match in 'src_alt' but matches in 'src'. However 'src_alt/lib' exists, so this might be an error.")
      end

      context 'when a resource file pattern does not match any files in src or src_alt' do
        let(:resource_file_patterns) { ['lib2/*'] }

        it 'raises an error' do
          expect {
            builder.build
          }.to raise_error("Package '#{resource_name}' has a glob that resolves to an empty file list: lib2/*")
        end
      end
    end

    context 'when specifying files to exclude' do
      let(:resource_file_patterns) { ['**/*'] }
      let(:matched_blobs) { ['matched.tgz'] }
      let(:excluded_blobs) { ['excluded.tgz'] }
      let(:excluded_src) { ['.git'] }
      let(:excluded_file_patterns) { ['.git', 'excluded.tgz', 'unmatched.txt'] }

      before do
        release_source.add_files('src', matched_files + excluded_src)
        release_source.add_files('blobs', matched_blobs + excluded_blobs)
      end

      it 'the exclusions are not found in the build directory' do
        builder.build
        explosion = open_archive(builder.tarball_path)
        expect(directory_listing(explosion)).to contain_exactly(*(matched_files + matched_blobs))
      end
    end
  end

  describe 'the generated resource fingerprint' do
    let(:resource_file_patterns) { ['lib/*.rb', 'README.*'] }
    let(:matched_files) { ['lib/1.rb', 'lib/2.rb', 'README.2', 'README.md'] }
    let(:reference_fingerprint) { 'f0b1b81bd6b8093f2627eaa13952a1aab8b125d1' }

    before { matched_files.each { |f| release_source.add_file('src', f, "contents of #{f}") } }

    it 'is used as the version' do
      builder.build
      expect(builder.resource_version).to eq(reference_fingerprint)
    end

    it 'is based on the matched files, ignoring unmatched files' do
      release_source.add_file('src', 'an-unmatched-file.txt')
      expect(builder.fingerprint).to eq(reference_fingerprint)
    end

    it 'varies with the set of matched files' do
      release_source.add_file('src', 'lib/a_matched_file.rb')
      expect(builder.fingerprint).to_not eq(reference_fingerprint)
    end

    it 'varies with the content of matched files' do
      release_source.add_file('src', 'lib/1.rb', 'varied contents')
      expect(builder.fingerprint).to_not eq(reference_fingerprint)
    end

    context 'when a file pattern matches empty directories' do
      let(:resource_file_patterns) { ['lib/*.rb', 'README.*', 'tmp'] }

      it 'varies' do
        release_source.add_dir('src/tmp')
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file pattern matches a dotfile' do
      before { release_source.add_file('src', 'lib/.zb.rb') }

      it 'the dotfile is included in the fingerprint' do
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary in order' do
      let(:resource_deps) { ['bar', 'foo'] }

      it 'does not vary' do
        expect(builder.fingerprint).to eq(reference_fingerprint)
      end
    end

    context 'when dependencies vary' do
      let(:resource_deps) { ['foo', 'bar', 'baz'] }

      it 'varies' do
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when blobs are present' do
      let(:resource_file_patterns) { ['lib/*.rb', 'README.*', '*.tgz'] }
      before { release_source.add_file('blobs', 'matched.tgz') }

      it 'varies' do
        expect(builder.fingerprint).to_not eq(reference_fingerprint)
      end
    end

    context 'when a file comes from blobs instead of src' do
      before { FileUtils.mv(release_source.join('src', 'README.md'), release_source.join('blobs', 'README.md')) }

      it 'does not vary' do
        expect(builder.fingerprint).to eq(reference_fingerprint)
      end
    end

    context 'when the resource contains a src_alt dir' do
      it 'includes top-level files from src_alt instead of src' do
        release_source.add_file('src_alt', 'README.md', 'README.md from src_alt')
        builder.build
        expect(builder.fingerprint).not_to eq(reference_fingerprint)
      end
    end
  end

  describe 'pre_packaging script' do
    let(:temp_file) { Tempfile.new('pre_packaging.out') }
    before { release_source.add_file('src', '2.rb') }
    after { temp_file.unlink }

    it 'is executed as part of the build' do
      release_source.add_file('packages', "#{resource_name}/pre_packaging",
        "echo 'Luke I am your father.' > #{temp_file.path}; exit 0")

      builder.build
      expect(temp_file.read).to eq("Luke I am your father.\n")
    end

    context 'if the script exits with non-zero' do
      it 'causes the builder to raise' do
        release_source.add_file('packages', "#{resource_name}/pre_packaging", 'exit 1')

        expect {
          builder.build
        }.to raise_error(Bosh::Cli::InvalidPackage, "'#{resource_name}' pre-packaging failed")
      end
    end
  end

  describe 'using pre-built versions' do
    let(:resource_file_patterns) { ['foo/**/*', 'baz'] }
    let(:fingerprint) { 'fake-fingerprint' }
    let(:final_storage_dir) { ".final_builds/packages/#{resource_name}" }
    let(:dev_storage_dir) { ".dev_builds/packages/#{resource_name}" }

    before do
      allow(Digest::SHA1).to receive(:hexdigest).and_return(fingerprint)
      release_source.add_files('src', ['foo/foo.rb', 'foo/lib/1.rb', 'foo/lib/2.rb', 'foo/README', 'baz'])
    end

    context 'when a final version is available locally' do
      before { release_source.add_version(fingerprint, final_storage_dir, 'payload', {'version' => fingerprint, 'blobstore_id' => '12321'}) }

      it 'should use the final version' do
        builder.build
        expect(builder.tarball_path).to eq(release_source.join('.final_builds', 'packages', resource_name, "#{fingerprint}.tgz"))
      end
    end

    context 'when a dev version is available locally' do
      before { release_source.add_version(fingerprint, dev_storage_dir, 'dev_payload', {'version' => fingerprint}) }

      it 'should use the final version' do
        builder.build
        expect(builder.tarball_path).to eq(release_source.join('.dev_builds', 'packages', resource_name, "#{fingerprint}.tgz"))
      end

      context 'and a final version is also available locally' do
        before { release_source.add_version(fingerprint, final_storage_dir, 'payload', {'version' => fingerprint, 'blobstore_id' => '12321'}) }

        it 'should use the final version' do
          builder.build
          expect(builder.tarball_path).to eq(release_source.join('.final_builds', 'packages', resource_name, "#{fingerprint}.tgz"))
        end
      end
    end

    context 'when a final or dev version is not available locally' do
      it 'generates a tarball and saves it as a dev build' do
        builder.build
        expect(builder.tarball_path).to eq(release_source.join('.dev_builds', 'packages', resource_name, "#{fingerprint}.tgz"))
      end
    end
  end
end
