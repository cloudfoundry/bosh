require 'spec_helper'

module Bosh::Cli
  describe ReleaseBuilder do
    let(:release_name) { 'bosh-release' }

    before do
      @release_source = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(@release_source, 'config'))
      @release = Bosh::Cli::Release.new(@release_source)
    end

    def new_builder(options = {})
      ReleaseBuilder.new(@release, [], [], release_name, options)
    end

    context 'when there is a final release' do
      it 'bumps the least significant segment for the next version' do
        final_storage_dir = File.join(@release_source, 'releases', release_name)
        final_index = Versions::VersionsIndex.new(final_storage_dir)

        final_index.add_version('deadbeef', { 'version' => '7.4.1' })
        final_index.add_version('deadcafe', { 'version' => '7.3.1' })

        builder = new_builder(final: true)
        expect(builder.version).to eq('7.4.2')
        builder.build
      end

      it 'creates a dev version in sync with latest final version' do
        final_storage_dir = File.join(@release_source, 'releases', release_name)
        final_index = Versions::VersionsIndex.new(final_storage_dir)

        final_index.add_version('deadbeef', { 'version' => '7.4' })
        final_index.add_version('deadcafe', { 'version' => '7.3.1' })

        builder = new_builder
        expect(builder.version).to eq('7.4+dev.1')
        builder.build
      end

      it 'bumps the dev version matching the latest final release' do
        final_storage_dir = File.join(@release_source, 'releases', release_name)
        final_index = Versions::VersionsIndex.new(final_storage_dir)

        final_index.add_version('deadbeef', { 'version' => '7.3' })
        final_index.add_version('deadcafe', { 'version' => '7.2' })

        dev_storage_dir = File.join(@release_source, 'dev_releases', release_name)
        dev_index = Versions::VersionsIndex.new(dev_storage_dir)

        dev_index.add_version('deadabcd', { 'version' => '7.4.1-dev' })
        dev_index.add_version('deadbeef', { 'version' => '7.3.2.1-dev' })
        dev_index.add_version('deadturkey', { 'version' => '7.3.2-dev' })
        dev_index.add_version('deadcafe', { 'version' => '7.3.1-dev' })

        builder = new_builder
        expect(builder.version).to eq('7.3+dev.3')
        builder.build
      end
    end

    context 'when there are no final releases' do
      it 'starts with version 0+dev.1' do
        expect(new_builder.version).to eq('0+dev.1')
      end

      it 'increments the dev version' do
        dev_storage_dir = File.join(@release_source, 'dev_releases', release_name)
        dev_index = Versions::VersionsIndex.new(dev_storage_dir)

        dev_index.add_version('deadbeef', { 'version' => '0.1-dev' })

        expect(new_builder.version).to eq('0+dev.2')
      end
    end

    it 'builds a release' do
      builder = new_builder
      builder.build

      expected_tarball_path = File.join(@release_source,
        'dev_releases',
        release_name,
        "#{release_name}-0+dev.1.tgz")

      expect(builder.tarball_path).to eq(expected_tarball_path)
      expect(File).to exist(expected_tarball_path)
    end

    it 'should include git hash and uncommitted change state in manifest' do
      builder = new_builder({commit_hash: '12345678', uncommitted_changes: true})
      builder.build

      manifest = Psych.load_file(builder.manifest_path)
      expect(manifest['commit_hash']).to eq('12345678')
      expect(manifest['uncommitted_changes']).to be(true)
    end

    it 'allows building a new release when no content has changed' do
      release_path = File.join(@release_source, 'dev_releases', release_name)
      expect(File).to_not exist(File.join(release_path, "#{release_name}-0+dev.1.tgz"))

      new_builder.build
      expect(File).to exist(File.join(release_path, "#{release_name}-0+dev.1.tgz"))
      expect(File).to_not exist(File.join(release_path, "#{release_name}-0+dev.2.tgz"))

      new_builder.build
      expect(File).to exist(File.join(release_path, "#{release_name}-0+dev.2.tgz"))
    end

    it 'errors when trying to re-create the same final version' do
      new_builder({:version => '1', :final => true}).build
      expect(File).to exist(File.join(@release_source, 'releases', release_name, "#{release_name}-1.tgz"))

      expect{
        new_builder({:version => '1', :final => true}).build
      }.to raise_error(ReleaseVersionError, 'Release version already exists')
    end

    it 'has a list of jobs affected by building this release' do
      jobs = []
      jobs << double(:job, :new_version? => true, :packages => %w(bar baz), :name => 'job1')
      jobs << double(:job, :new_version? => false, :packages => %w(foo baz), :name => 'job2')
      jobs << double(:job, :new_version? => false, :packages => %w(baz zb), :name => 'job3')
      jobs << double(:job, :new_version? => false, :packages => %w(bar baz), :name => 'job4')

      packages = []
      packages << double(:package, :name => 'foo', :new_version? => true)
      packages << double(:package, :name => 'bar', :new_version? => false)
      packages << double(:package, :name => 'baz', :new_version? => false)
      packages << double(:package, :name => 'zb', :new_version? => true)

      builder = ReleaseBuilder.new(@release, packages, jobs, release_name)

      expect(builder.affected_jobs).to eq(jobs[0...-1]) # exclude last job
    end

    it 'has packages and jobs fingerprints in spec' do
      job = double(
        JobBuilder,
        :name => 'job1',
        :version => '1.1',
        :new_version? => true,
        :packages => %w(foo),
        :fingerprint => 'deadbeef',
        :checksum => 'cafebad'
      )

      package = double(
        Resources::Package,
        :name => 'foo',
        :version => '42',
        :new_version? => true,
        :fingerprint => 'deadcafe',
        :checksum => 'baddeed',
        :dependencies => []
      )

      builder = ReleaseBuilder.new(@release, [package], [job], release_name)
      expect(builder).to receive(:copy_jobs)
      expect(builder).to receive(:copy_packages)

      builder.build

      manifest = Psych.load_file(builder.manifest_path)

      expect(manifest['jobs'][0]['fingerprint']).to eq('deadbeef')
      expect(manifest['packages'][0]['fingerprint']).to eq('deadcafe')
    end

    context 'when version options is passed into initializer' do
      context 'when creating final release' do
        context 'when given release version already exists' do
          it 'raises error' do
            final_storage_dir = File.join(@release_source, 'releases', release_name)
            final_index = Versions::VersionsIndex.new(final_storage_dir)

            final_index.add_version('deadbeef', { 'version' => '7.3' })

            FileUtils.touch(File.join(final_storage_dir, "#{release_name}-7.3.tgz"))

            expect { new_builder({ final: true, version: '7.3' }) }.to raise_error(ReleaseVersionError, 'Release version already exists')
          end
        end

        context 'when given version does not exist' do
          it 'uses given version' do
            builder = new_builder({ final: true, version: '3.123' })
            expect(builder.version).to eq('3.123')
            builder.build
          end
        end
      end

      context 'when creating dev release' do
        it 'does not allow a version to be specified for dev releases' do
          builder = new_builder({ final: true, version: '3.123' })
          expect(builder.version).to eq('3.123')
          builder.build

          expect{ new_builder({ version: '3.123.1-dev' }) }.to raise_error(
            ReleaseVersionError,
            'Version numbers cannot be specified for dev releases'
          )
        end
      end
    end
  end
end
