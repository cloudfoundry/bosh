require 'spec_helper'
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
        its(:number) { should eq('local') }

        it 'uses LocalDownloadAdapater as download adapter' do
          download_adapter = instance_double('Bosh::Dev::LocalDownloadAdapter')
          Bosh::Dev::LocalDownloadAdapter
            .should_receive(:new)
            .with(logger)
            .and_return(download_adapter)

          build = instance_double('Bosh::Dev::Build::Local')
          Bosh::Dev::Build::Local
            .should_receive(:new)
            .with('local', download_adapter)
            .and_return(build)

          subject.should == build
        end
      end
    end

    let(:job_name) { 'current_job' }
    let(:download_directory) { '/FAKE/CUSTOM/WORK/DIRECTORY' }
    let(:access_key_id) { 'FAKE_ACCESS_KEY_ID' }
    let(:secret_access_key) { 'FAKE_SECRET_ACCESS_KEY' }
    let(:fog_storage) do
      Fog::Storage.new(
        provider: 'AWS',
        aws_access_key_id: access_key_id,
        aws_secret_access_key: secret_access_key,
      )
    end

    let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }

    subject(:build) { Build::Candidate.new('123', download_adapter) }

    before(:all) { Fog.mock! }
    after(:all) { Fog.unmock! }

    before do
      Bosh::Dev::UploadAdapter.stub(:new).and_return(upload_adapter)

      Fog::Mock.reset
      fog_storage.directories.create(key: 'bosh-ci-pipeline')
      fog_storage.directories.create(key: 'bosh-jenkins-artifacts')

      stub_const(
        'ENV',
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => secret_access_key,
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => access_key_id
      )
    end

    describe '#upload' do
      let(:release) { double(tarball: 'release-tarball.tgz') }
      let(:io) { double }

      it 'uploads the release with its build number' do
        File.stub(:open).with(release.tarball) { io }
        upload_adapter.should_receive(:upload).with(bucket_name: 'bosh-ci-pipeline', key: '123/release/bosh-123.tgz', body: io, public: true)

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
        upload_adapter.should_receive(:upload).with do |options|
          key = options.fetch(:key)
          body = options.fetch(:body)
          public = options.fetch(:public)

          expect(public).to eq(true)

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

      before do
        Bosh::Dev::UploadAdapter.unstub!(:new)
        Rake::FileUtilsExt.stub(:sh)
        Bosh::Stemcell::Archive.stub(new: stemcell)
      end

      it 'syncs the pipeline gems' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose sync s3://bosh-ci-pipeline/123/gems/ s3://bosh-jenkins-gems')

        subject.promote_artifacts
      end

      it 'syncs the releases' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/release/bosh-123.tgz s3://bosh-jenkins-artifacts/release/bosh-123.tgz')

        subject.promote_artifacts
      end

      it 'syncs the bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/aws/bosh-stemcell-123-aws-xen-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/aws/bosh-stemcell-123-aws-xen-ubuntu.tgz')
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz')
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/openstack/bosh-stemcell-123-openstack-kvm-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/openstack/bosh-stemcell-123-openstack-kvm-ubuntu.tgz')
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/vsphere/bosh-stemcell-123-vsphere-esxi-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/vsphere/bosh-stemcell-123-vsphere-esxi-ubuntu.tgz')

        subject.promote_artifacts
      end

      it 'syncs the latest bosh stemcells' do
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz')
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz')
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/openstack/bosh-stemcell-latest-openstack-kvm-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/openstack/bosh-stemcell-latest-openstack-kvm-ubuntu.tgz')
        Rake::FileUtilsExt.should_receive(:sh).
          with('s3cmd --verbose cp s3://bosh-ci-pipeline/123/bosh-stemcell/vsphere/bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz s3://bosh-jenkins-artifacts/bosh-stemcell/vsphere/bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz')

        subject.promote_artifacts
      end

      describe 'update light bosh ami pointer file' do
        let(:fake_stemcell_filename) { 'FAKE_STEMCELL_FILENAME' }
        let(:fake_stemcell) { instance_double('Bosh::Stemcell::Archive') }
        let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base', name: 'aws') }
        let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Ubuntu') }
        let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: fake_stemcell_filename) }
        let(:bucket_files) { fog_storage.directories.get('bosh-jenkins-artifacts').files }

        before do
          Bosh::Stemcell::Infrastructure.stub(:for).with('aws').and_return(infrastructure)
          Bosh::Stemcell::OperatingSystem.stub(:for).with('ubuntu').and_return(operating_system)

          Bosh::Stemcell::ArchiveFilename.stub(:new).and_return(archive_filename)

          fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')
          Bosh::Stemcell::Archive.stub(new: fake_stemcell)

          stub_request(:get, 'http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/FAKE_STEMCELL_FILENAME')
        end

        it 'downloads the aws bosh-stemcell for the current build' do
          subject.should_receive(:download_stemcell).
            with(infrastructure: infrastructure, name: 'bosh-stemcell', light: true)

          subject.promote_artifacts
        end

        it 'initializes a Stemcell with the downloaded stemcell filename' do
          Bosh::Stemcell::ArchiveFilename.should_receive(:new).
            with('123', infrastructure, operating_system, 'bosh-stemcell', true).and_return(archive_filename)

          Bosh::Stemcell::Archive.should_receive(:new).with(fake_stemcell_filename)

          subject.promote_artifacts
        end

        it 'updates the S3 object with the AMI ID from the stemcell.MF' do
          fake_stemcell.stub(ami_id: 'FAKE_AMI_ID')

          subject.promote_artifacts

          expect(bucket_files.get('last_successful-bosh-stemcell-aws_ami_us-east-1').body).to eq('FAKE_AMI_ID')
        end

        it 'is publicly reachable' do
          subject.promote_artifacts

          expect(bucket_files.get('last_successful-bosh-stemcell-aws_ami_us-east-1').public_url).to_not be_nil
        end
      end
    end

    describe '#upload_stemcell' do
      let(:logger) { instance_double('Logger').as_null_object }
      let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }

      before do
        Bosh::Dev::UploadAdapter.unstub!(:new)

        FileUtils.mkdir('/tmp')
        File.open(stemcell.path, 'w') { |f| f.write(stemcell_contents) }
        Logger.stub(new: logger)
      end

      describe 'when publishing a full stemcell' do
        let(:stemcell) do
          instance_double(
            'Bosh::Stemcell::Archive',
            light?: false,
            path: 'unused',
            infrastructure: 'vsphere',
            name: 'stemcell-name'
          )
        end
        let(:stemcell_contents) { 'contents of the stemcells' }

        it 'publishes a stemcell to an S3 bucket' do
          key = '123/bosh-stemcell/vsphere/bosh-stemcell-123-vsphere-esxi-ubuntu.tgz'
          logger.should_receive(:info).with("uploaded to s3://bosh-ci-pipeline/#{key}")
          build.upload_stemcell(stemcell)
          expect(bucket_files.map(&:key)).to include(key)
          expect(bucket_files.get(key).body).to eq('contents of the stemcells')
        end

        it 'updates the latest stemcell in the S3 bucket' do
          key = '123/bosh-stemcell/vsphere/bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz'
          logger.should_receive(:info).with("uploaded to s3://bosh-ci-pipeline/#{key}")
          build.upload_stemcell(stemcell)
          expect(bucket_files.map(&:key)).to include(key)
          expect(bucket_files.get(key).body).to eq('contents of the stemcells')
        end
      end

      describe 'when publishing a light stemcell' do
        let(:stemcell) do
          instance_double(
            'Bosh::Stemcell::Archive',
            light?: true,
            path: 'unused',
            infrastructure: 'vsphere',
            name: 'stemcell-name'
          )
        end
        let(:stemcell_contents) { 'this file is a light stemcell' }

        it 'publishes a light stemcell to S3 bucket' do
          key = '123/bosh-stemcell/vsphere/light-bosh-stemcell-123-vsphere-esxi-ubuntu.tgz'
          logger.should_receive(:info).with("uploaded to s3://bosh-ci-pipeline/#{key}")
          build.upload_stemcell(stemcell)
          expect(bucket_files.map(&:key)).to include(key)
          expect(bucket_files.get(key).body).to eq('this file is a light stemcell')
        end

        it 'updates the latest light stemcell in the s3 bucket' do
          key = '123/bosh-stemcell/vsphere/light-bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz'
          logger.should_receive(:info).with("uploaded to s3://bosh-ci-pipeline/#{key}")
          build.upload_stemcell(stemcell)
          expect(bucket_files.map(&:key)).to include(key)
          expect(bucket_files.get(key).body).to eq('this file is a light stemcell')
        end
      end
    end

    describe '#download_stemcell' do
      let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }

      context 'when not specifying a download directory' do
        it 'downloads the specified stemcell version from the pipeline bucket' do
          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/bosh-stemcell-123-aws-xen-ubuntu.tgz')
          build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: false)
        end

        context 'when remote file does not exist' do
          it 'raises' do
            download_adapter.stub(:download).and_raise 'hell'

            expect {
              build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('vsphere'), name: 'fooey', light: false)
            }.to raise_error 'hell'
          end
        end

        it 'downloads the specified light stemcell version from the pipeline bucket' do
          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/light-bosh-stemcell-123-aws-xen-ubuntu.tgz')
          build.download_stemcell(infrastructure: Bosh::Stemcell::Infrastructure.for('aws'), name: 'bosh-stemcell', light: true)
        end

        it 'returns the name of the downloaded file' do
          options = {
            infrastructure: Bosh::Stemcell::Infrastructure.for('aws'),
            name: 'bosh-stemcell',
            light: true,
            output_directory: '/fake/artifacts/dir',
          }

          download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/bosh-stemcell/aws/light-bosh-stemcell-123-aws-xen-ubuntu.tgz'), '/fake/artifacts/dir/light-bosh-stemcell-123-aws-xen-ubuntu.tgz')
          expect(build.download_stemcell(options)).to eq 'light-bosh-stemcell-123-aws-xen-ubuntu.tgz'
        end
      end
    end

    describe '#bosh_stemcell_path' do
      let(:infrastructure) { Bosh::Stemcell::Infrastructure::Aws.new }

      it 'works' do
        expect(subject.bosh_stemcell_path(infrastructure, download_directory)).to eq(File.join(download_directory, 'light-bosh-stemcell-123-aws-xen-ubuntu.tgz'))
      end
    end
  end

  describe Build::Candidate do
    subject(:build) { Build::Candidate.new('123', download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }

    describe '#release_tarball_path' do
      context 'when remote file does not exist' do
        it 'raises' do
          download_adapter.stub(:download).and_raise 'error'
          expect { build.release_tarball_path }.to raise_error 'error'
        end
      end

      it 'downloads the specified release from the pipeline bucket' do
        download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/release/bosh-123.tgz'), 'tmp/bosh-123.tgz')
        build.release_tarball_path
      end

      it 'returns the relative path of the downloaded release' do
        download_adapter.should_receive(:download).with(URI('http://bosh-ci-pipeline.s3.amazonaws.com/123/release/bosh-123.tgz'), 'tmp/bosh-123.tgz')
        expect(build.release_tarball_path).to eq 'tmp/bosh-123.tgz'
      end
    end
  end

  describe Build::Local do
    subject { described_class.new('123', download_adapter) }
    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }

    before(:all) { Fog.mock! }
    after(:all)  { Fog.unmock! }

    describe '#release_tarball_path' do
      let(:micro_bosh_release) { instance_double('Bosh::Dev::MicroBoshRelease', tarball: '/fake/path/to/release/tarball') }

      before { Bosh::Dev::MicroBoshRelease.stub(new: micro_bosh_release) }

      it 'returns the path to new microbosh release' do
        expect(subject.release_tarball_path).to eq('/fake/path/to/release/tarball')
      end
    end

    describe '#download_stemcell' do
      let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter') }

      context 'when downloading does not result in an error' do
        it 'uses download adapter to move stemcell to given location' do
          download_adapter
            .should_receive(:download)
            .with('bosh-stemcell-123-aws-xen-ubuntu.tgz', '/output-directory/bosh-stemcell-123-aws-xen-ubuntu.tgz')
          subject.download_stemcell(
            infrastructure: Bosh::Stemcell::Infrastructure.for('aws'),
            name: 'bosh-stemcell',
            light: false,
            output_directory: '/output-directory',
          )
        end
      end

      context 'when downloading results in an error' do
        it 'propagates raised error' do
          error = RuntimeError.new('error-message')
          download_adapter.stub(:download).and_raise(error)

          expect {
            subject.download_stemcell(
              infrastructure: Bosh::Stemcell::Infrastructure.for('vsphere'),
              light: false,
              name: 'stemcell-name',
            )
          }.to raise_error(error)
        end
      end
    end
  end
end
