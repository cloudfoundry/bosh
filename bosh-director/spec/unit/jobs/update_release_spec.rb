require 'spec_helper'
require 'support/release_helper'

module Bosh::Director
  describe Jobs::UpdateRelease do
    let(:blobstore) { double('Blobstore') }

    before(:each) do
      # Stubbing the blobstore used in BlobUtil :( needs refactoring
      App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      @release_dir = Dir.mktmpdir('release_dir')
    end

    after(:each) do
      FileUtils.remove_entry_secure(@release_dir) if File.exist?(@release_dir)
    end

    describe 'Resque job class expectations' do
      let(:job_type) { :update_release }
      it_behaves_like 'a Resque job'
    end

    describe 'updating a release' do
      let(:manifest) do
        {
          'name' => 'appcloud',
          'version' => '42.6-dev',
          'commit_hash' => '12345678',
          'uncommitted_changes' => 'true',
          'jobs' => [],
          'packages' => []
        }
      end

      context 'processing update release' do
        it 'with a local release' do
          job = Jobs::UpdateRelease.new(@release_dir)
          job.should_not_receive(:download_remote_release)
          job.should_receive(:extract_release)
          job.should_receive(:verify_manifest)
          job.should_receive(:process_release)

          job.perform
        end

        it 'with a remote release' do
          job = Jobs::UpdateRelease.new(@release_dir, {'remote' => true, 'location' => 'release_location'})
          job.should_receive(:download_remote_release)
          job.should_receive(:extract_release)
          job.should_receive(:verify_manifest)
          job.should_receive(:process_release)

          job.perform
        end
      end

      context 'commit_hash and uncommitted changes flag' do
        it 'sets commit_hash and uncommitted changes flag on release_version' do
          release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
          job = Jobs::UpdateRelease.new(release_dir)
          job.extract_release
          job.verify_manifest
          job.process_release

          rv = Models::ReleaseVersion.filter(version: '42+dev.6').first

          rv.should_not be_nil
          rv.commit_hash.should == '12345678'
          rv.uncommitted_changes.should be(true)
        end

        it 'sets default commit_hash and uncommitted_changes flag if missing' do
          manifest.delete('commit_hash')
          manifest.delete('uncommitted_changes')
          release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
          job = Jobs::UpdateRelease.new(release_dir)
          job.extract_release
          job.verify_manifest
          job.process_release

          rv = Models::ReleaseVersion.filter(version: '42+dev.6').first

          rv.should_not be_nil
          rv.commit_hash.should == 'unknown'
          rv.uncommitted_changes.should be(false)
        end
      end

      context 'extracting a release' do
        it 'should fail if cannot extract release archive' do
          result = Bosh::Exec::Result.new('cmd', 'output', 1)
          Bosh::Exec.should_receive(:sh).and_return(result)

          release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)
          job = Jobs::UpdateRelease.new(release_dir)

          expect {
            job.extract_release
          }.to raise_exception(Bosh::Director::ReleaseInvalidArchive)
        end
      end
    end

    describe 'rebasing release' do
      let(:manifest) do
        {
          'name' => 'appcloud',
          'version' => '42.6-dev',
          'jobs' => [
            {
              'name' => 'baz',
              'version' => '33',
              'templates' => {
                'bin/test.erb' => 'bin/test',
                'config/zb.yml.erb' => 'config/zb.yml'
              },
              'packages' => %w(foo bar),
              'fingerprint' => 'job-fingerprint-1'
            },
            {
              'name' => 'zaz',
              'version' => '0.2-dev',
              'templates' => {},
              'packages' => %w(bar),
              'fingerprint' => 'job-fingerprint-2'
            },
            {
              'name' => 'zbz',
              'version' => '666',
              'templates' => {},
              'packages' => %w(zbb),
              'fingerprint' => 'job-fingerprint-3'
            }
          ],
          'packages' => [
            {
              'name' => 'foo',
              'version' => '2.33-dev',
              'dependencies' => %w(bar),
              'fingerprint' => 'package-fingerprint-1',
              'sha1' => 'package-sha1-1'
            },
            {
              'name' => 'bar',
              'version' => '3.14-dev',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-2',
              'sha1' => 'package-sha1-2'
            },
            {
              'name' => 'zbb',
              'version' => '333',
              'dependencies' => [],
              'fingerprint' => 'package-fingerprint-3',
              'sha1' => 'package-sha1-3'
            }
          ]
        }
      end

      before do
        @release_dir = Test::ReleaseHelper.new.create_release_tarball(manifest)

        @job = Jobs::UpdateRelease.new(@release_dir, 'rebase' => true)

        @release = Models::Release.make(name: 'appcloud')
        @rv = Models::ReleaseVersion.make(release: @release, version: '37')

        Models::Package.make(release: @release, name: 'foo', version: '2.7-dev')
        Models::Package.make(release: @release, name: 'bar', version: '42')

        Models::Template.make(release: @release, name: 'baz', version: '33.7-dev')
        Models::Template.make(release: @release, name: 'zaz', version: '17')

        # create up to 6 new blobs (3*job + 3*package)
        allow(blobstore).to receive(:create).at_most(6).and_return('b1', 'b2', 'b3', 'b4', 'b5', 'b6')
        # get is only called when a blob is copied
        allow(blobstore).to receive(:get)
        allow(@job).to receive(:with_release_lock).with('appcloud').and_yield
      end

      it 'rebases the release version' do
        @job.perform

        # No previous release exists with the same release version (42).
        # So the default dev post-release version is used (semi-semantic format).
        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first

        expect(rv).to_not be_nil
      end

      context 'when the package fingerprint matches one in the database' do
        before do
          Models::Package.make(
            release: @release,
            name: 'zbb',
            version: '25',
            fingerprint: 'package-fingerprint-3',
            sha1: 'package-sha1-old',
          )
        end

        it 'creates new package (version) with copied blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(1).times # copies the existing 'zbb' package
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          zbbs.map(&:version).should =~ %w(25 333)

          # Fingerprints are the same because package contents did not change
          zbbs.map(&:fingerprint).should =~ %w(package-fingerprint-3 package-fingerprint-3)

          # SHA1s are the same because first blob was copied
          zbbs.map(&:sha1).should =~ %w(package-sha1-old package-sha1-old)
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          rv.packages.map(&:version).should =~ %w(2.33-dev 3.14-dev 333)
          rv.packages.map(&:fingerprint).should =~ %w(package-fingerprint-1 package-fingerprint-2 package-fingerprint-3)
          rv.packages.map(&:sha1).should =~ %w(package-sha1-1 package-sha1-2 package-sha1-old)
        end
      end

      context 'when the package fingerprint matches multiple in the database' do
        before do
          Models::Package.make(release: @release, name: 'zbb', version: '25', fingerprint: 'package-fingerprint-3', sha1: 'package-sha1-25')
          Models::Package.make(release: @release, name: 'zbb', version: '26', fingerprint: 'package-fingerprint-3', sha1: 'package-sha1-26')
        end

        it 'creates new package (version) with copied blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(1).times # copies the existing 'zbb' package
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          zbbs.map(&:version).should =~ %w(26 25 333)

          # Fingerprints are the same because package contents did not change
          zbbs.map(&:fingerprint).should =~ %w(package-fingerprint-3 package-fingerprint-3 package-fingerprint-3)

          # SHA1s are the same because first blob was copied
          zbbs.map(&:sha1).should =~ %w(package-sha1-25 package-sha1-25 package-sha1-26)
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          rv.packages.map(&:version).should =~ %w(2.33-dev 3.14-dev 333)
          rv.packages.map(&:fingerprint).should =~ %w(package-fingerprint-1 package-fingerprint-2 package-fingerprint-3)
          rv.packages.map(&:sha1).should =~ %w(package-sha1-1 package-sha1-2 package-sha1-25)
        end
      end

      context 'when the package fingerprint is new' do
        before do
          Models::Package.make(release: @release, name: 'zbb', version: '25', fingerprint: 'package-fingerprint-old', sha1: 'package-sha1-25')
        end

        it 'creates new package (version) with new blob (sha1)' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all
          zbbs.map(&:version).should =~ %w(25 333)

          # Fingerprints are different because package contents are different
          zbbs.map(&:fingerprint).should =~ %w(package-fingerprint-old package-fingerprint-3)

          # SHA1s are different because package tars are different
          zbbs.map(&:sha1).should =~ %w(package-sha1-25 package-sha1-3)
        end

        it 'associates newly created packages to the release version' do
          @job.perform

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          rv.packages.map(&:version).should =~ %w(2.33-dev 3.14-dev 333)
          rv.packages.map(&:fingerprint).should =~ %w(package-fingerprint-1 package-fingerprint-2 package-fingerprint-3)
          rv.packages.map(&:sha1).should =~ %w(package-sha1-1 package-sha1-2 package-sha1-3)
        end
      end

      context 'when the job fingerprint matches one in the database' do
        before do
          Models::Template.make(release: @release, name: 'zbz', version: '28', fingerprint: 'job-fingerprint-3')
        end

        it 'uses the new job blob' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all
          zbzs.map(&:version).should =~ %w(28 666)
          zbzs.map(&:fingerprint).should =~ %w(job-fingerprint-3 job-fingerprint-3)

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          rv.templates.map(&:fingerprint).should =~ %w(job-fingerprint-1 job-fingerprint-2 job-fingerprint-3)
        end
      end

      context 'when the job fingerprint is new' do
        before do
          Models::Template.make(release: @release, name: 'zbz', version: '28', fingerprint: 'job-fingerprint-old')
        end

        it 'uses the new job blob' do
          expect(blobstore).to receive(:create).exactly(6).times # creates new blobs for each package & job
          expect(blobstore).to receive(:get).exactly(0).times # does not copy any existing packages or jobs
          @job.perform

          zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all
          zbzs.map(&:version).should =~ %w(28 666)
          zbzs.map(&:fingerprint).should =~ %w(job-fingerprint-old job-fingerprint-3)

          rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first
          rv.templates.map(&:fingerprint).should =~ %w(job-fingerprint-1 job-fingerprint-2 job-fingerprint-3)
        end
      end

      it 'uses major+dev.1 version for initial rebase if no version exists' do
        @rv.destroy
        Models::Package.each { |p| p.destroy }
        Models::Template.each { |t| t.destroy }

        @job.perform

        foos = Models::Package.filter(release_id: @release.id, name: 'foo').all
        bars = Models::Package.filter(release_id: @release.id, name: 'bar').all

        foos.map { |foo| foo.version }.should =~ %w(2.33-dev)
        bars.map { |bar| bar.version }.should =~ %w(3.14-dev)

        bazs = Models::Template.filter(release_id: @release.id, name: 'baz').all
        zazs = Models::Template.filter(release_id: @release.id, name: 'zaz').all

        bazs.map { |baz| baz.version }.should =~ %w(33)
        zazs.map { |zaz| zaz.version }.should =~ %w(0.2-dev)

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42+dev.1').first

        rv.packages.map { |p| p.version }.should =~ %w(2.33-dev 3.14-dev 333)
        rv.templates.map { |t| t.version }.should =~ %w(0.2-dev 33 666)
      end

      it 'performs no rebase if same release is being rebased twice' do
        dup_release_dir = Dir.mktmpdir
        FileUtils.cp(File.join(@release_dir, 'release.tgz'), dup_release_dir)

        @job.perform

        job = Jobs::UpdateRelease.new(dup_release_dir, 'rebase' => true)
        job.should_receive(:with_release_lock).with('appcloud').and_yield

        expect {
          job.perform
        }.to raise_error(/Rebase is attempted without any job or package change/)
      end
    end

    describe 'create_package' do
      before do
        @release = Models::Release.make
        @job = Jobs::UpdateRelease.new(@release_dir)
        @job.release_model = @release
      end

      it 'should create simple packages' do
        FileUtils.mkdir_p(File.join(@release_dir, 'packages'))
        package_path = File.join(@release_dir, 'packages', 'test_package.tgz')

        File.open(package_path, 'w') do |f|
          f.write(create_package({'test' => 'test contents'}))
        end

        blobstore.should_receive(:create).
          with(satisfy { |obj| obj.path == package_path }).
          and_return('blob_id')

        @job.create_package(
          {
            'name' => 'test_package',
            'version' => '1.0',
            'sha1' => 'some-sha',
            'dependencies' => %w(foo_package bar_package)
          }
        )

        package = Models::Package[name: 'test_package', version: '1.0']
        package.should_not be_nil
        package.name.should == 'test_package'
        package.version.should == '1.0'
        package.release.should == @release
        package.sha1.should == 'some-sha'
        package.blobstore_id.should == 'blob_id'
      end

      it 'should copy package blob' do
        BlobUtil.should_receive(:copy_blob).and_return('blob_id')
        FileUtils.mkdir_p(File.join(@release_dir, 'packages'))
        package_path = File.join(@release_dir, 'packages', 'test_package.tgz')
        File.open(package_path, 'w') do |f|
          f.write(create_package({'test' => 'test contents'}))
        end

        @job.create_package({'name' => 'test_package',
                             'version' => '1.0', 'sha1' => 'some-sha',
                             'dependencies' => ['foo_package', 'bar_package'],
                             'blobstore_id' => 'blah'})

        package = Models::Package[name: 'test_package', version: '1.0']
        package.should_not be_nil
        package.name.should == 'test_package'
        package.version.should == '1.0'
        package.release.should == @release
        package.sha1.should == 'some-sha'
        package.blobstore_id.should == 'blob_id'
      end

      it 'should fail if cannot extract package archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        Bosh::Exec.should_receive(:sh).and_return(result)

        expect {
          @job.create_package(
            {
              'name' => 'test_package',
              'version' => '1.0',
              'sha1' => 'some-sha',
              'dependencies' => %w(foo_package bar_package)
            }
          )
        }.to raise_exception(Bosh::Director::PackageInvalidArchive)
      end

      def create_package(files)
        io = StringIO.new

        Archive::Tar::Minitar::Writer.open(io) do |tar|
          files.each do |key, value|
            tar.add_file(key, {:mode => "0644", :mtime => 0}) { |os, _| os.write(value) }
          end
        end

        io.close
        gzip(io.string)
      end
    end

    describe 'resolve_package_dependencies' do
      before(:each) do
        @job = Jobs::UpdateRelease.new(@release_dir)
      end

      it 'should normalize nil dependencies' do
        packages = [{'name' => 'A'}, {'name' => 'B', 'dependencies' => ['A']}]
        @job.resolve_package_dependencies(packages)
        packages.should eql([
                              {'dependencies' => [], 'name' => 'A'},
                              {'dependencies' => ['A'], 'name' => 'B'}
                            ])
      end

      it 'should not allow cycles' do
        packages = [
          {'name' => 'A', 'dependencies' => ['B']},
          {'name' => 'B', 'dependencies' => ['A']}
        ]

        lambda {
          @job.resolve_package_dependencies(packages)
        }.should raise_exception
      end

      it 'should resolve nested dependencies' do
        packages = [
          {'name' => 'A', 'dependencies' => ['B']},
          {'name' => 'B', 'dependencies' => ['C']}, {'name' => 'C'}
        ]

        @job.resolve_package_dependencies(packages)
        packages.should eql([
                              {'dependencies' => ['B', 'C'], 'name' => 'A'},
                              {'dependencies' => ['C'], 'name' => 'B'},
                              {'dependencies' => [], 'name' => 'C'}
                            ])
      end
    end

    describe 'create jobs' do
      before do
        @release = Models::Release.make
        @tarball = File.join(@release_dir, 'jobs', 'foo.tgz')
        @job_bits = create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}})

        @job_attrs = {'name' => 'foo', 'version' => '1', 'sha1' => 'deadbeef'}

        FileUtils.mkdir_p(File.dirname(@tarball))

        @job = Jobs::UpdateRelease.new(@release_dir)
        @job.release_model = @release
      end

      it 'should create a proper template and upload job bits to blobstore' do
        File.open(@tarball, 'w') { |f| f.write(@job_bits) }

        blobstore.should_receive(:create) do |f|
          f.rewind
          Digest::SHA1.hexdigest(f.read).should == Digest::SHA1.hexdigest(@job_bits)

          Digest::SHA1.hexdigest(f.read)
        end

        Models::Template.count.should == 0
        @job.create_job(@job_attrs)

        template = Models::Template.first
        template.name.should == 'foo'
        template.version.should == '1'
        template.release.should == @release
        template.sha1.should == 'deadbeef'
      end

      it 'should fail if cannot extract job archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        Bosh::Exec.should_receive(:sh).and_return(result)

        expect { @job.create_job(@job_attrs) }.to raise_error(JobInvalidArchive)
      end

      it 'whines on missing manifest' do
        @job_no_mf =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_manifest: true)

        File.open(@tarball, 'w') { |f| f.write(@job_no_mf) }

        lambda { @job.create_job(@job_attrs) }.should raise_error(JobMissingManifest)
      end

      it 'whines on missing monit file' do
        @job_no_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_monit: true)
        File.open(@tarball, 'w') { |f| f.write(@job_no_monit) }

        lambda { @job.create_job(@job_attrs) }.should raise_error(JobMissingMonit)
      end

      it 'does not whine when it has a foo.monit file' do
        blobstore.stub(:create).and_return('fake-blobstore-id')
        @job_no_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, monit_file: 'foo.monit')

        File.open(@tarball, 'w') { |f| f.write(@job_no_monit) }

        expect { @job.create_job(@job_attrs) }.to_not raise_error
      end

      it 'whines on missing template' do
        @job_no_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_templates: ['foo'])

        File.open(@tarball, 'w') { |f| f.write(@job_no_monit) }

        lambda { @job.create_job(@job_attrs) }.should raise_error(JobMissingTemplateFile)
      end
    end

    def create_job(name, monit, configuration_files, options = { })
      io = StringIO.new

      manifest = {
        "name" => name,
        "templates" => {},
        "packages" => []
      }

      configuration_files.each do |path, configuration_file|
        manifest["templates"][path] = configuration_file["destination"]
      end

      Archive::Tar::Minitar::Writer.open(io) do |tar|
        unless options[:skip_manifest]
          tar.add_file("job.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
        end
        unless options[:skip_monit]
          monit_file = options[:monit_file] ? options[:monit_file] : "monit"
          tar.add_file(monit_file, {:mode => "0644", :mtime => 0}) { |os, _| os.write(monit) }
        end

        tar.mkdir("templates", {:mode => "0755", :mtime => 0})
        configuration_files.each do |path, configuration_file|
          unless options[:skip_templates] && options[:skip_templates].include?(path)
            tar.add_file("templates/#{path}", {:mode => "0644", :mtime => 0}) do |os, _|
              os.write(configuration_file["contents"])
            end
          end
        end
      end

      io.close

      gzip(io.string)
    end
  end
end
