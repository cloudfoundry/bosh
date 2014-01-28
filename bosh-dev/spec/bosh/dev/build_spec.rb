require 'spec_helper'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/dev/build'

module Bosh::Dev
  describe Build do
    include FakeFS::SpecHelpers

    describe '.candidate' do
      subject { described_class.candidate(logger) }
      let(:logger) { Logger.new('/dev/null') }

      context 'when CANDIDATE_BUILD_NUMBER is set' do
        before { stub_const('ENV', 'CANDIDATE_BUILD_NUMBER' => 'candidate') }

        it { should be_a(Build::Candidate) }
        its(:number) { should eq('candidate') }

        it 'uses DownloadAdapater as download adapter' do
          download_adapter = instance_double('Bosh::Dev::DownloadAdapter')
          Bosh::Dev::DownloadAdapter
            .should_receive(:new)
            .with(logger)
            .and_return(download_adapter)

          build = instance_double('Bosh::Dev::Build::Local')
          Bosh::Dev::Build::Candidate
            .should_receive(:new)
            .with('candidate', download_adapter)
            .and_return(build)

          subject.should == build
        end
      end

      context 'when CANDIDATE_BUILD_NUMBER is not set' do
        it { should be_a(Build::Local) }
        its(:number) { should eq('0000') }

        it 'uses LocalDownloadAdapater as download adapter' do
          download_adapter = instance_double('Bosh::Dev::LocalDownloadAdapter')
          Bosh::Dev::LocalDownloadAdapter
            .should_receive(:new)
            .with(logger)
            .and_return(download_adapter)

          build = instance_double('Bosh::Dev::Build::Local')
          Bosh::Dev::Build::Local
            .should_receive(:new)
            .with('0000', download_adapter)
            .and_return(build)

          subject.should == build
        end
      end
    end

    let(:access_key_id) { 'FAKE_ACCESS_KEY_ID' }
    let(:secret_access_key) { 'FAKE_SECRET_ACCESS_KEY' }
    let(:fog_storage) do
      Fog::Storage.new(
        provider: 'AWS',
        aws_access_key_id: access_key_id,
        aws_secret_access_key: secret_access_key,
      )
    end

    subject(:build) { Build::Candidate.new('123', download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }

    before(:all) { Fog.mock! }
    after(:all) { Fog.unmock! }

    before do
      Fog::Mock.reset
      fog_storage.directories.create(key: 'bosh-ci-pipeline')
      fog_storage.directories.create(key: 'bosh-jenkins-artifacts')
      stub_const('ENV', {
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => secret_access_key,
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => access_key_id
      })
    end

    describe '#upload_release' do
      let(:release) do
        instance_double(
          'Bosh::Dev::BoshRelease',
          final_tarball_path: 'fake-release-tarball-path',
        )
      end

      before { Bosh::Dev::UploadAdapter.stub(:new).and_return(upload_adapter) }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter', upload: nil) }

      it 'uploads the release with its build number' do
        io = double('io')
        File.stub(:open).with('fake-release-tarball-path') { io }
        upload_adapter.should_receive(:upload).with(
          bucket_name: 'bosh-ci-pipeline',
          key: '123/release/bosh-123.tgz',
          body: io,
          public: true,
        )
        subject.upload_release(release)
      end

      context 'when the file does not exist' do
        it 'raises an error' do
          expect { subject.upload_release(release) }.to raise_error(Errno::ENOENT)
        end
      end
    end

    describe '#upload_gems' do
      let(:src) { 'source_dir' }
      let(:dst) { 'dest_dir' }
      let(:files) { %w(foo/bar.txt foo/bar/baz.txt) }
      let(:logger) { instance_double('Logger').as_null_object }

      before { Bosh::Dev::UploadAdapter.stub(:new).and_return(upload_adapter) }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }

      before do
        FileUtils.mkdir_p(src)
        Dir.chdir(src) do
          files.each do |path|
            FileUtils.mkdir_p(File.dirname(path))
            File.open(path, 'w') { |f| f.write("Contents of #{path}") }
          end
        end
        Logger.stub(new: logger)
      end

      it 'recursively uploads a directory into base_dir' do
        upload_adapter.should_receive(:upload) do |options|
          key = options.fetch(:key)
          body = options.fetch(:body)
          public = options.fetch(:public)

          expect(public).to be(true)

          case key
            when '123/dest_dir/foo/bar.txt'
              expect(body.read).to eq('Contents of foo/bar.txt')
            when '123/dest_dir/foo/bar/baz.txt'
              expect(body.read).to eq('Contents of foo/bar/baz.txt')
            else
              raise "unexpected key: #{key}"
          end
        end.exactly(2).times.and_return(double('uploaded file', public_url: nil))

        subject.upload_gems(src, dst)
      end
    end

    describe '#promote_artifacts' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Archive', ami_id: 'ami-ID') }

      let(:promotable_artifacts) do
        instance_double('Bosh::Dev::PromotableArtifacts', all: [
          instance_double('Bosh::Dev::GemArtifact', promote: nil),
          instance_double('Bosh::Dev::PromotableArtifact', promote: nil),
          instance_double('Bosh::Dev::LightStemcellPointer', promote: nil),
        ])
      end

      before do
        Rake::FileUtilsExt.stub(:sh)
        Bosh::Stemcell::Archive.stub(new: stemcell)
        PromotableArtifacts.stub(new: promotable_artifacts)
      end

      it 'promotes all PromotableArtifacts' do
        promotable_artifacts.all.each do |artifact|
          artifact.should_receive(:promote)
        end

        subject.promote_artifacts
      end
    end

    describe '#upload_stemcell' do
      let(:logger) { instance_double('Logger').as_null_object }
      let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter', upload: nil) }

      before do
        FileUtils.mkdir('/tmp')
        File.open(stemcell.path, 'w') { |f| f.write(stemcell_contents) }
        Logger.stub(new: logger)
        Bosh::Dev::UploadAdapter.stub(:new).and_return(upload_adapter)
      end

      describe 'when publishing a full stemcell' do
        let(:stemcell) do
          instance_double(
            'Bosh::Stemcell::Archive',
            light?: false,
            path: '/tmp/bosh-stemcell-123-vsphere-esxi-ubuntu.tgz',
            infrastructure: 'vsphere',
            name: 'stemcell-name'
          )
        end
        let(:stemcell_contents) { 'contents of the stemcells' }

        it 'uses the upload adapter to upload the numbered and latest stemcell to s3' do
          key = '123/bosh-stemcell/vsphere/bosh-stemcell-123-vsphere-esxi-ubuntu.tgz'
          latest_key = '123/bosh-stemcell/vsphere/bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz'

          logger.should_receive(:info).with("uploaded to s3://bosh-ci-pipeline/#{key}")

          upload_adapter.should_receive(:upload).with(bucket_name: 'bosh-ci-pipeline',
                                                      key: key,
                                                      body: anything,
                                                      public: true)

          upload_adapter.should_receive(:upload).with(bucket_name: 'bosh-ci-pipeline',
                                                      key: latest_key,
                                                      body: anything,
                                                      public: true)

          build.upload_stemcell(stemcell)
        end
      end

      describe 'when publishing a light stemcell' do
        let(:stemcell) do
          instance_double(
            'Bosh::Stemcell::Archive',
            light?: true,
            path: '/tmp/light-bosh-stemcell-123-vsphere-esxi-ubuntu.tgz',
            infrastructure: 'vsphere',
            name: 'stemcell-name'
          )
        end

        let(:stemcell_contents) { 'this file is a light stemcell' }

        it 'publishes a light stemcell to S3 bucket' do
          key = '123/bosh-stemcell/vsphere/light-bosh-stemcell-123-vsphere-esxi-ubuntu.tgz'
          latest_key = '123/bosh-stemcell/vsphere/light-bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz'

          logger.should_receive(:info).with("uploaded to s3://bosh-ci-pipeline/#{key}")

          upload_adapter.should_receive(:upload).with(bucket_name: 'bosh-ci-pipeline',
                                                      key: key,
                                                      body: anything,
                                                      public: true)

          upload_adapter.should_receive(:upload).with(bucket_name: 'bosh-ci-pipeline',
                                                      key: latest_key,
                                                      body: anything,
                                                      public: true)

          build.upload_stemcell(stemcell)
        end
      end
    end

    describe '#download_stemcell' do
      def perform(light = false)
        build.download_stemcell('stemcell-name', definition, light, Dir.pwd)
      end

      let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'fake-filename') }

      before do
        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return(archive_filename)
      end

      let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base', name: 'infrastructure-name') }
      let(:definition) { instance_double('Bosh::Stemcell::Definition', infrastructure: infrastructure) }

      let(:expected_s3_bucket) { 'http://bosh-ci-pipeline.s3.amazonaws.com' }
      let(:expected_s3_folder) { '/123/stemcell-name/infrastructure-name' }

      it 'downloads the specified non-light stemcell version from the pipeline bucket' do
        expected_uri = URI("#{expected_s3_bucket}#{expected_s3_folder}/#{archive_filename}")
        download_adapter.should_receive(:download).with(expected_uri, "/#{archive_filename}")
        perform

        expect(Bosh::Stemcell::ArchiveFilename).to have_received(:new).with('123', definition, 'stemcell-name', false)
      end

      it 'downloads the specified light stemcell version from the pipeline bucket' do
        expected_uri = URI("#{expected_s3_bucket}#{expected_s3_folder}/#{archive_filename}")
        download_adapter.should_receive(:download).with(expected_uri, "/#{archive_filename}")
        perform(true)

        expect(Bosh::Stemcell::ArchiveFilename).to have_received(:new).with('123', definition, 'stemcell-name', true)
      end

      it 'returns the name of the downloaded file' do
        download_adapter.should_receive(:download)
        perform.should eq(archive_filename.to_s)
      end
    end

    describe '#bosh_stemcell_path' do

      let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'fake-filename') }

      before do
        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return(archive_filename)
      end

      let(:infrastructure) do
        instance_double(
          'Bosh::Stemcell::Infrastructure::Base',
          light?: true,
        )
      end

      let(:definition) {
        instance_double(
          'Bosh::Stemcell::Definition',
          infrastructure: infrastructure,
        )
      }

      it 'returns the bosh stemcell path for given definition' do
        download_directory = '/FAKE/CUSTOM/WORK/DIRECTORY'
        bosh_stemcell_path = subject.bosh_stemcell_path(definition, download_directory)
        expect(bosh_stemcell_path).to eq(File.join(download_directory, archive_filename.to_s))
        expect(Bosh::Stemcell::ArchiveFilename).to have_received(:new).with('123', definition, 'bosh-stemcell', true)
      end
    end
  end

  describe Build::Candidate do
    subject(:build) { Build::Candidate.new('123', download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }

    describe '#release_tarball_path' do
      context 'when remote file does not exist' do
        it 'raises an exception' do
          error = Exception.new('error-message')
          download_adapter.stub(:download).and_raise(error)
          expect { build.release_tarball_path }.to raise_error(error)
        end
      end

      it 'downloads the specified release from the pipeline bucket' do
        uri = URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/release/bosh-123.tgz')
        download_adapter.should_receive(:download).with(uri, 'tmp/bosh-123.tgz')
        build.release_tarball_path
      end

      it 'returns the relative path of the downloaded release' do
        uri = URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/release/bosh-123.tgz')
        download_adapter.should_receive(:download).with(uri, 'tmp/bosh-123.tgz')
        expect(build.release_tarball_path).to eq('tmp/bosh-123.tgz')
      end
    end

    describe '#light_stemcell' do
      let(:archive_filename) {
        instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'fake-filename')
      }

      let(:archive) {
        instance_double('Bosh::Stemcell::Archive')
      }

      before do
        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return(archive_filename)
        allow(UriProvider).to receive(:pipeline_uri).and_return('fake-url')
        allow(Dir).to receive(:pwd).and_return('current-dir')
        allow(download_adapter).to receive(:download)
        allow(Bosh::Stemcell::Archive).to receive(:new).and_return(archive)
      end

      it 'fetches the light stemcell for aws + ubuntu + ruby agent' do
        subject.light_stemcell

        expect(UriProvider).to have_received(:pipeline_uri).with('123/bosh-stemcell/aws', 'fake-filename')
        expect(download_adapter).to have_received(:download).with('fake-url', 'current-dir/fake-filename')
      end

      it 'returns the path to a light stemcell' do
        actual_archive = subject.light_stemcell
        expect(actual_archive).to eq archive
      end
    end
  end

  describe Build::Local do
    subject { described_class.new('build-number', download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }

    before(:all) { Fog.mock! }
    after(:all) { Fog.unmock! }

    describe '#release_tarball_path' do
      let(:dev_bosh_release) { instance_double('Bosh::Dev::BoshRelease') }
      before { Bosh::Dev::BoshRelease.stub(build: dev_bosh_release) }

      let(:gem_components) { instance_double('Bosh::Dev::GemComponents') }
      before { allow(GemComponents).to receive(:new).with('build-number').and_return(gem_components) }

      it 'builds gems before creating release because the latter depends on the presence of release gems' do
        expect(gem_components).to receive(:build_release_gems).ordered
        expect(dev_bosh_release).to receive(:dev_tarball_path).ordered

        subject.release_tarball_path
      end

      it 'returns the path to new dev bosh release' do
        allow(dev_bosh_release).to receive(:dev_tarball_path).and_return('fake-dev-tarball-path')
        allow(gem_components).to receive(:build_release_gems)

        expect(subject.release_tarball_path).to eq('fake-dev-tarball-path')
      end
    end

    describe '#download_stemcell' do
      def perform
        subject.download_stemcell('stemcell-name', definition, false, '/output-directory')
      end

      let(:archive_filename) {
        instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'fake-filename')
      }

      let(:definition) {
        instance_double(
          'Bosh::Stemcell::Definition',
        )
      }

      before do
        allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return(archive_filename)
      end

      context 'when downloading does not result in an error' do
        it 'uses download adapter to move stemcell to given location' do
          download_adapter
            .should_receive(:download)
            .with("tmp/#{archive_filename}", "/output-directory/#{archive_filename}")
          filename = perform

          expect(filename).to eq(archive_filename.to_s)
          expect(Bosh::Stemcell::ArchiveFilename).to have_received(:new).with('build-number', definition, 'stemcell-name', false)
        end
      end

      context 'when downloading results in an error' do
        it 'propagates raised error' do
          error = RuntimeError.new('error-message')
          download_adapter.stub(:download).and_raise(error)
          expect { perform }.to raise_error(error)
        end
      end
    end
  end
end
