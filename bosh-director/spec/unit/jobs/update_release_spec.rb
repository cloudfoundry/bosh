# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

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
          release_dir = ReleaseHelper.create_release_tarball(manifest)
          job = Jobs::UpdateRelease.new(release_dir)
          job.extract_release
          job.verify_manifest
          job.process_release

          rv = Models::ReleaseVersion.filter(version: '42.6-dev').first

          rv.should_not be_nil
          rv.commit_hash.should == '12345678'
          rv.uncommitted_changes.should be(true)
        end

        it 'sets default commit_hash and uncommitted_changes flag if missing' do
          manifest.delete('commit_hash')
          manifest.delete('uncommitted_changes')
          release_dir = ReleaseHelper.create_release_tarball(manifest)
          job = Jobs::UpdateRelease.new(release_dir)
          job.extract_release
          job.verify_manifest
          job.process_release

          rv = Models::ReleaseVersion.filter(version: '42.6-dev').first

          rv.should_not be_nil
          rv.commit_hash.should == 'unknown'
          rv.uncommitted_changes.should be(false)
        end
      end

      context 'extracting a release' do
        it 'should fail if cannot extract release archive' do
          result = Bosh::Exec::Result.new('cmd', 'output', 1)
          Bosh::Exec.should_receive(:sh).and_return(result)

          release_dir = ReleaseHelper.create_release_tarball(manifest)
          job = Jobs::UpdateRelease.new(release_dir)

          expect {
            job.extract_release
          }.to raise_exception(Bosh::Director::ReleaseInvalidArchive)
        end
      end
    end

    describe 'rebasing release' do
      before(:each) do
        @manifest = {
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
              'fingerprint' => 'deadbeef'
            },
            {
              'name' => 'zaz',
              'version' => '0.2-dev',
              'templates' => {},
              'packages' => %w(bar),
              'fingerprint' => 'badcafe'
            },
            {
              'name' => 'zbz',
              'version' => '666',
              'templates' => {},
              'packages' => %w(zbb),
              'fingerprint' => 'baddead'
            }
          ],
          'packages' => [
            {
              'name' => 'foo',
              'version' => '2.33-dev',
              'dependencies' => %w(bar),
              'fingerprint' => 'deadbeef'
            },
            {
              'name' => 'bar',
              'version' => '3.14-dev',
              'dependencies' => [],
              'fingerprint' => 'badcafe'
            },
            {
              'name' => 'zbb',
              'version' => '333',
              'dependencies' => [],
              'fingerprint' => 'deadbad'
            }
          ]
        }

        @release_dir = ReleaseHelper.create_release_tarball(@manifest)

        @job = Jobs::UpdateRelease.new(@release_dir, 'rebase' => true)

        @release = Models::Release.make(name: 'appcloud')
        @rv = Models::ReleaseVersion.make(release: @release, version: '37')

        Models::Package.make(release: @release, name: 'foo', version: '2.7-dev')
        Models::Package.make(release: @release, name: 'bar', version: '42')
        Models::Package.make(release: @release, name: 'zbb', version: '25', fingerprint: 'deadbad')

        Models::Template.make(release: @release, name: 'baz', version: '33.7-dev')
        Models::Template.make(release: @release, name: 'zaz', version: '17')
        Models::Template.make(release: @release, name: 'zbz', version: '28', fingerprint: 'baddead')
      end

      it 'rebases original versions saving the major version' do
        blobstore.should_receive(:create).
          exactly(4).times.and_return('b1', 'b2', 'b3', 'b4')
        @job.should_receive(:with_release_lock).with('appcloud').and_yield
        @job.perform

        foos = Models::Package.filter(release_id: @release.id, name: 'foo').all
        bars = Models::Package.filter(release_id: @release.id, name: 'bar').all
        zbbs = Models::Package.filter(release_id: @release.id, name: 'zbb').all

        foos.map { |foo| foo.version }.should =~ %w(2.7-dev 2.8-dev)
        bars.map { |bar| bar.version }.should =~ %w(42 3.1-dev)
        zbbs.map { |zbb| zbb.version }.should =~ %w(25) # fingerprint match

        bazs = Models::Template.filter(release_id: @release.id, name: 'baz').all
        zazs = Models::Template.filter(release_id: @release.id, name: 'zaz').all
        zbzs = Models::Template.filter(release_id: @release.id, name: 'zbz').all

        bazs.map { |baz| baz.version }.should =~ %w(33 33.7-dev)
        zazs.map { |zaz| zaz.version }.should =~ %w(17 0.1-dev)
        zbzs.map { |zbz| zbz.version }.should =~ %w(28) # fingerprint match

        rv = Models::ReleaseVersion.filter(
          release_id: @release.id, version: '42.1-dev').first

        rv.should_not be_nil

        rv.packages.map { |package| package.version }.should =~ %w(2.8-dev 3.1-dev 25)

        rv.templates.map { |template| template.version }.should =~ %w(33 0.1-dev 28)
      end

      it 'uses major.1-dev version for initial rebase if no version exists' do
        blobstore.should_receive(:create).
          exactly(6).times.and_return('b1', 'b2', 'b3', 'b4', 'b5', 'b6')

        @rv.destroy
        Models::Package.each { |p| p.destroy }
        Models::Template.each { |t| t.destroy }

        @job.should_receive(:with_release_lock).with('appcloud').and_yield
        @job.perform

        foos = Models::Package.filter(release_id: @release.id, name: 'foo').all
        bars = Models::Package.filter(release_id: @release.id, name: 'bar').all

        foos.map { |foo| foo.version }.should =~ %w(2.1-dev)
        bars.map { |bar| bar.version }.should =~ %w(3.1-dev)

        bazs = Models::Template.filter(release_id: @release.id, name: 'baz').all
        zazs = Models::Template.filter(release_id: @release.id, name: 'zaz').all

        bazs.map { |baz| baz.version }.should =~ %w(33)
        zazs.map { |zaz| zaz.version }.should =~ %w(0.1-dev)

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42.1-dev').first

        rv.packages.map { |p| p.version }.should =~ %w(2.1-dev 3.1-dev 333)
        rv.templates.map { |t| t.version }.should =~ %w(33 0.1-dev 666)
      end

      it 'performs no rebase if same release is being rebased twice' do
        dup_release_dir = Dir.mktmpdir
        FileUtils.cp(File.join(@release_dir, 'release.tgz'), dup_release_dir)

        blobstore.should_receive(:create).
          exactly(4).times.and_return('b1', 'b2', 'b3', 'b4')
        @job.should_receive(:with_release_lock).with('appcloud').and_yield
        @job.perform

        job = Jobs::UpdateRelease.new(dup_release_dir, 'rebase' => true)
        job.should_receive(:with_release_lock).with('appcloud').and_yield

        expect {
          job.perform
        }.to raise_error(/Rebase is attempted without any job or package change/)
      end

      it 'prefers the same name/version, then final version, ' +
           'then version with most compiled packages' +
           "when there's more than one match" do
        Models::Package.each { |p| p.destroy }
        Models::Template.each { |t| t.destroy }

        Models::Package.make(release: @release, name: 'bar', version: '3.14-dev', fingerprint: 'badcafe')

        Models::Package.make(release: @release, name: 'bar', version: '52', fingerprint: 'badcafe')

        zbb1 = Models::Package.make(release: @release, name: 'zbb', version: '22.1-dev', fingerprint: 'deadbad')

        zbb2 = Models::Package.make(release: @release, name: 'zbb', version: '22.2-dev', fingerprint: 'deadbad')

        Models::CompiledPackage.make(package: zbb1)
        2.times do
          Models::CompiledPackage.make(package: zbb2)
        end

        Models::Template.make(release: @release, name: 'baz', version: '332.1-dev', fingerprint: 'deadbeef')

        Models::Template.make(release: @release, name: 'baz', version: '333', fingerprint: 'deadbeef')

        blobstore.should_receive(:create).
          exactly(3).times.and_return('b1', 'b2', 'b3')
        @job.should_receive(:with_release_lock).with('appcloud').and_yield
        @job.perform

        rv = Models::ReleaseVersion.filter(release_id: @release.id, version: '42.1-dev').first

        rv.packages.select { |p| p.name == 'bar' }.map { |p| p.version }.should =~ %w(3.14-dev)

        rv.packages.select { |p| p.name == 'zbb' }.map { |p| p.version }.should =~ %w(22.2-dev)

        rv.templates.select { |t| t.name == 'baz' }.map { |t| t.version }.should =~ %w(333)
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

        blobstore.should_receive(:create).with(
          have_a_path_of(package_path)).and_return('blob_id')

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

        blobstore.should_receive(:create).and_return do |f|
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
  end
end
