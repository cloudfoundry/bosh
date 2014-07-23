require 'spec_helper'

module Bosh::Cli
  describe ReleaseBuilder do

    before do
      @release_dir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(@release_dir, 'config'))
      @release = Bosh::Cli::Release.new(@release_dir)
    end

    def new_builder(options = {})
      Bosh::Cli::ReleaseBuilder.new(@release, [], [], options)
    end

    context 'when there is a final release' do
      it 'bumps the least significant segment for the next version' do
        final_storage_dir = File.join(@release_dir, 'releases')
        final_index = Bosh::Cli::VersionsIndex.new(final_storage_dir)

        final_index.add_version('deadbeef', { 'version' => '7.4.1' })
        final_index.add_version('deadcafe', { 'version' => '7.3.1' })

        builder = new_builder(final: true)
        builder.version.should == '7.4.2'
        builder.build
      end

      it 'creates a dev version in sync with latest final version' do
        final_storage_dir = File.join(@release_dir, 'releases')
        final_index = Bosh::Cli::VersionsIndex.new(final_storage_dir)

        final_index.add_version('deadbeef', { 'version' => '7.4' })
        final_index.add_version('deadcafe', { 'version' => '7.3.1' })

        builder = new_builder
        builder.version.should == '7.4+dev.1'
        builder.build
      end

      it 'bumps the dev version matching the latest final release' do
        final_storage_dir = File.join(@release_dir, 'releases')
        final_index = Bosh::Cli::VersionsIndex.new(final_storage_dir)

        final_index.add_version('deadbeef', { 'version' => '7.3' })
        final_index.add_version('deadcafe', { 'version' => '7.2' })

        dev_storage_dir = File.join(@release_dir, 'dev_releases')
        dev_index = Bosh::Cli::VersionsIndex.new(dev_storage_dir)

        dev_index.add_version('deadabcd', { 'version' => '7.4.1-dev' })
        dev_index.add_version('deadbeef', { 'version' => '7.3.2.1-dev' })
        dev_index.add_version('deadturkey', { 'version' => '7.3.2-dev' })
        dev_index.add_version('deadcafe', { 'version' => '7.3.1-dev' })

        builder = new_builder
        builder.version.should == '7.3+dev.3'
        builder.build
      end
    end

    context 'when there are no final releases' do
      it 'starts with version 0+dev.1' do
        new_builder.version.should == '0+dev.1'
      end

      it 'increments the dev version' do
        dev_storage_dir = File.join(@release_dir, 'dev_releases')
        dev_index = Bosh::Cli::VersionsIndex.new(dev_storage_dir)

        dev_index.add_version('deadbeef', { 'version' => '0.1-dev' })

        new_builder.version.should == '0+dev.2'
      end
    end

    it 'builds a release' do
      builder = new_builder
      builder.build

      expected_tarball_path = File.join(@release_dir,
        'dev_releases',
        'bosh_release-0+dev.1.tgz')

      builder.tarball_path.should == expected_tarball_path
      File.file?(expected_tarball_path).should be(true)
    end

    it 'should include git hash and uncommitted change state in manifest' do
      options = {commit_hash: '12345678', uncommitted_changes: true}
      builder = Bosh::Cli::ReleaseBuilder.new(@release, [], [], options)
      builder.build

      manifest = Psych.load_file(builder.manifest_path)
      manifest['commit_hash'].should == '12345678'
      manifest['uncommitted_changes'].should be(true)
    end

    it 'allows building a new release when no content has changed' do
      expect(File).to_not exist(File.join(@release_dir, 'dev_releases', 'bosh_release-0+dev.1.tgz'))

      new_builder.build
      expect(File).to exist(File.join(@release_dir, 'dev_releases', 'bosh_release-0+dev.1.tgz'))
      expect(File).to_not exist(File.join(@release_dir, 'dev_releases', 'bosh_release-0+dev.2.tgz'))

      new_builder.build
      expect(File).to exist(File.join(@release_dir, 'dev_releases', 'bosh_release-0+dev.2.tgz'))
    end

    it 'errors when trying to re-create the same final version' do
      new_builder({:version => '1', :final => true}).build
      expect(File).to exist(File.join(@release_dir, 'releases', 'bosh_release-1.tgz'))

      expect{
        new_builder({:version => '1', :final => true}).build
      }.to raise_error(Bosh::Cli::ReleaseVersionError, 'Release version already exists')
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

      builder = Bosh::Cli::ReleaseBuilder.new(@release, packages, jobs)

      expect(builder.affected_jobs).to eq(jobs[0...-1]) # exclude last job
    end

    it 'has packages and jobs fingerprints in spec' do
      job = double(
        Bosh::Cli::JobBuilder,
        :name => 'job1',
        :version => '1.1',
        :new_version? => true,
        :packages => %w(foo),
        :fingerprint => 'deadbeef',
        :checksum => 'cafebad'
      )

      package = double(
        Bosh::Cli::PackageBuilder,
        :name => 'foo',
        :version => '42',
        :new_version? => true,
        :fingerprint => 'deadcafe',
        :checksum => 'baddeed',
        :dependencies => []
      )

      builder = Bosh::Cli::ReleaseBuilder.new(@release, [package], [job])
      builder.should_receive(:copy_jobs)
      builder.should_receive(:copy_packages)

      builder.build

      manifest = Psych.load_file(builder.manifest_path)

      manifest['jobs'][0]['fingerprint'].should == 'deadbeef'
      manifest['packages'][0]['fingerprint'].should == 'deadcafe'
    end

    context 'when version options is passed into initializer' do
      context 'when creating final release' do
        context 'when given release version already exists' do
          it 'raises error' do
            final_storage_dir = File.join(@release_dir, 'releases')
            final_index = Bosh::Cli::VersionsIndex.new(final_storage_dir)

            final_index.add_version('deadbeef', { 'version' => '7.3' })

            FileUtils.touch(File.join(@release_dir, 'releases', 'bosh_release-7.3.tgz'))

            expect { new_builder({ final: true, version: '7.3' }) }.to raise_error(Bosh::Cli::ReleaseVersionError, 'Release version already exists')
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
            Bosh::Cli::ReleaseVersionError,
            'Version numbers cannot be specified for dev releases'
          )
        end
      end
    end
  end
end
