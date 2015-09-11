require 'spec_helper'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/dev/build'

module Bosh::Dev
  describe Build do
    include FakeFS::SpecHelpers

    let(:bucket_name) { 'fake-bucket' }

    describe '.candidate' do
      subject { described_class.candidate(bucket_name) }

      context 'when CANDIDATE_BUILD_NUMBER is set' do
        before { stub_const('ENV', 'CANDIDATE_BUILD_NUMBER' => 'candidate') }

        it { should be_a(Build::Candidate) }
        its(:number) { should eq('candidate') }
        its(:bucket) { should eq('fake-bucket') }

        it 'uses DownloadAdapater as download adapter' do
          download_adapter = instance_double('Bosh::Dev::DownloadAdapter')
          expect(Bosh::Dev::DownloadAdapter)
            .to receive(:new)
            .with(logger)
            .and_return(download_adapter)

          build = instance_double('Bosh::Dev::Build::Local')
          expect(Bosh::Dev::Build::Candidate)
            .to receive(:new)
            .with('candidate', 'fake-bucket', download_adapter, logger)
            .and_return(build)

          expect(subject).to eq(build)
        end
      end

      context 'when CANDIDATE_BUILD_NUMBER is not set' do
        it { should be_a(Build::Local) }
        its(:number) { should eq('0000') }
        its(:bucket) { should eq('fake-bucket') }

        it 'uses LocalDownloadAdapater as download adapter' do
          download_adapter = instance_double('Bosh::Dev::LocalDownloadAdapter')
          expect(Bosh::Dev::LocalDownloadAdapter)
            .to receive(:new)
            .with(logger)
            .and_return(download_adapter)

          build = instance_double('Bosh::Dev::Build::Local')
          expect(Bosh::Dev::Build::Local)
            .to receive(:new)
            .with('0000', 'fake-bucket', download_adapter, logger)
            .and_return(build)

          expect(subject).to eq(build)
        end
      end
    end

    let(:access_key_id) { 'FAKE_ACCESS_KEY_ID' }
    let(:secret_access_key) { 'FAKE_SECRET_ACCESS_KEY' }

    subject(:build) { Build::Candidate.new('123', bucket_name, download_adapter, logger) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }
    let(:bucket_name) { 'fake-bucket' }

    describe '#upload_release' do
      let(:release) do
        instance_double(
          'Bosh::Dev::BoshRelease',
          final_tarball_path: 'fake-release-tarball-path',
        )
      end

      before { allow(Bosh::Dev::UploadAdapter).to receive(:new).and_return(upload_adapter) }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter', upload: nil) }

      it 'uploads the release with its build number' do
        io = double('io')
        allow(File).to receive(:open).with('fake-release-tarball-path') { io }
        expect(upload_adapter).to receive(:upload).with(
          bucket_name: bucket_name,
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

      before { allow(Bosh::Dev::UploadAdapter).to receive(:new).and_return(upload_adapter) }
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }

      before do
        FileUtils.mkdir_p(src)
        Dir.chdir(src) do
          files.each do |path|
            FileUtils.mkdir_p(File.dirname(path))
            File.open(path, 'w') { |f| f.write("Contents of #{path}") }
          end
        end
      end

      it 'recursively uploads a directory into base_dir' do
        expect(upload_adapter).to receive(:upload) do |options|
          bucket = options.fetch(:bucket_name)
          key = options.fetch(:key)
          body = options.fetch(:body)
          public = options.fetch(:public)

          expect(bucket).to be(bucket_name)
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

        build.upload_gems(src, dst)
      end
    end

    describe '#promote' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Archive') }

      let(:promotable_artifacts) do
        instance_double('Bosh::Dev::PromotableArtifacts', all: [
          instance_double('Bosh::Dev::GemArtifact', promote: nil, name: 'artifact.gem'),
          instance_double('Bosh::Dev::ReleaseArtifact', promote: nil, name: 'artifact.tgz'),
        ])
      end

      before do
        allow(Rake::FileUtilsExt).to receive(:sh)
        allow(Bosh::Stemcell::Archive).to receive(:new).and_return(stemcell)
        allow(PromotableArtifacts).to receive(:new).and_return(promotable_artifacts)
      end

      it 'promotes all PromotableArtifacts' do
        promotable_artifacts.all.each do |artifact|
          expect(artifact).to receive(:promoted?).and_return(false)
        end

        promotable_artifacts.all.each do |artifact|
          expect(artifact).to receive(:promote)
        end

        build.promote
      end

      it 'does not promote already promoted artifacts' do
        promotable_artifacts.all.each do |artifact|
          expect(artifact).to receive(:promoted?).and_return(true)
        end

        promotable_artifacts.all.each do |artifact|
          expect(artifact).to_not receive(:promote)
        end

        build.promote
      end
    end

    describe '#promoted?' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Archive') }

      let(:promotable_artifacts) do
        instance_double('Bosh::Dev::PromotableArtifacts', all: [
          instance_double('Bosh::Dev::GemArtifact', promote: nil, name: 'artifact.gem'),
          instance_double('Bosh::Dev::ReleaseArtifact', promote: nil, name: 'artifact.tgz'),
        ])
      end

      before do
        allow(Bosh::Stemcell::Archive).to receive(:new).and_return(stemcell)
        allow(PromotableArtifacts).to receive(:new).and_return(promotable_artifacts)
      end

      it 'returns true if all artifacts are promoted' do
        promotable_artifacts.all.each do |artifact|
          allow(artifact).to receive(:promoted?).and_return(true)
        end

        expect(build.promoted?).to be(true)
      end

      it 'returns false if any artifacts are not promoted' do
        allow(promotable_artifacts.all[0]).to receive(:promoted?).and_return(false)
        allow(promotable_artifacts.all[1]).to receive(:promoted?).and_return(true)

        expect(build.promoted?).to be(false)

        allow(promotable_artifacts.all[0]).to receive(:promoted?).and_return(true)
        allow(promotable_artifacts.all[1]).to receive(:promoted?).and_return(false)

        expect(build.promoted?).to be(false)
      end
    end

    describe '#upload_stemcell' do
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter', upload: nil) }

      before do
        FileUtils.mkdir('/tmp')
        File.open(stemcell_archive.path, 'w') { |f| f.write(stemcell_contents) }
        allow(Bosh::Dev::UploadAdapter).to receive(:new).and_return(upload_adapter)
      end

      describe 'when publishing a full stemcell' do
        let(:stemcell_archive) do
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

          expect(upload_adapter).to receive(:upload).with(bucket_name: bucket_name,
                                                      key: key,
                                                      body: anything,
                                                      public: true)

          expect(upload_adapter).to receive(:upload).with(bucket_name: bucket_name,
                                                      key: latest_key,
                                                      body: anything,
                                                      public: true)

          build.upload_stemcell(stemcell_archive)

          expect(log_string).to include("uploaded to s3://#{bucket_name}/#{key}")
        end
      end

      describe 'when publishing a light stemcell' do
        let(:stemcell_archive) do
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

          expect(upload_adapter).to receive(:upload).with(bucket_name: bucket_name,
                                                      key: key,
                                                      body: anything,
                                                      public: true)

          expect(upload_adapter).to receive(:upload).with(bucket_name: bucket_name,
                                                      key: latest_key,
                                                      body: anything,
                                                      public: true)

          build.upload_stemcell(stemcell_archive)

          expect(log_string).to include("uploaded to s3://#{bucket_name}/#{key}")
        end
      end
    end

    describe '#download_stemcell' do
      def perform
        build.download_stemcell(stemcell, Dir.pwd)
      end

      let(:stemcell) do
        instance_double('Bosh::Stemcell::Stemcell', name: 'fake-stemcell-name', infrastructure: infrastructure)
      end

      let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base', name: 'infrastructure-name') }

      let(:expected_s3_bucket) { 'http://bosh-ci-pipeline.s3.amazonaws.com' }
      let(:expected_s3_folder) { '/123/bosh-stemcell/infrastructure-name' }

      it 'downloads the specified stemcell version from the pipeline bucket' do
        expected_uri = URI("#{expected_s3_bucket}#{expected_s3_folder}/fake-stemcell-name")
        expect(download_adapter).to receive(:download).with(expected_uri, "/fake-stemcell-name")
        perform
      end

      it 'returns the name of the downloaded file' do
        expect(download_adapter).to receive(:download)
        expect(perform).to eq('fake-stemcell-name')
      end
    end
  end

  describe Build::Candidate do
    subject(:build) { Build::Candidate.new('123', bucket_name, download_adapter, logger) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }
    let(:bucket_name) { 'fake-bucket' }

    describe '#release_tarball_path' do
      context 'when remote file does not exist' do
        it 'raises an exception' do
          error = Exception.new('error-message')
          allow(download_adapter).to receive(:download).and_raise(error)
          expect { build.release_tarball_path }.to raise_error(error)
        end
      end

      it 'downloads the specified release from the pipeline bucket' do
        uri = URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/release/bosh-123.tgz')
        expect(download_adapter).to receive(:download).with(uri, 'tmp/bosh-123.tgz')
        build.release_tarball_path
      end

      it 'returns the relative path of the downloaded release' do
        uri = URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/release/bosh-123.tgz')
        expect(download_adapter).to receive(:download).with(uri, 'tmp/bosh-123.tgz')
        expect(build.release_tarball_path).to eq('tmp/bosh-123.tgz')
      end
    end
  end

  describe Build::Local do
    subject { described_class.new('build-number', bucket_name, download_adapter, logger) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }
    let(:bucket_name) { 'fake-bucket' }

    describe '#release_tarball_path' do
      let(:dev_bosh_release) { instance_double('Bosh::Dev::BoshRelease') }
      before { allow(Bosh::Dev::BoshRelease).to receive(:build).and_return(dev_bosh_release) }

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
        subject.download_stemcell(stemcell, '/output-directory')
      end

      let(:stemcell) do
        instance_double('Bosh::Stemcell::Stemcell', name: 'fake-stemcell-name')
      end

      context 'when downloading does not result in an error' do
        it 'uses download adapter to move stemcell to given location' do
          expect(download_adapter)
            .to receive(:download)
            .with('tmp/fake-stemcell-name', '/output-directory/fake-stemcell-name')
          filename = perform

          expect(filename).to eq('fake-stemcell-name')
        end
      end

      context 'when downloading results in an error' do
        it 'propagates raised error' do
          error = RuntimeError.new('error-message')
          allow(download_adapter).to receive(:download).and_raise(error)
          expect { perform }.to raise_error(error)
        end
      end
    end
  end
end
