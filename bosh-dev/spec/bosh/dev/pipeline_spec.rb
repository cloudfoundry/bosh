require 'spec_helper'
require 'bosh/dev/pipeline'

module Bosh::Dev
  describe Pipeline do
    include FakeFS::SpecHelpers

    let(:fog_storage) { Fog::Storage.new(provider: 'AWS', aws_access_key_id: 'fake access key', aws_secret_access_key: 'fake secret key') }
    let(:pipeline_storage) { Bosh::Dev::PipelineStorage.new }

    let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }
    let(:bucket_name) { 'bosh-ci-pipeline' }
    let(:logger) { instance_double('Logger').as_null_object }
    let(:build_id) { '456' }
    let(:download_directory) { '/FAKE/CUSTOM/WORK/DIRECTORY' }

    subject(:pipeline) { Pipeline.new(storage: pipeline_storage, logger: logger, build_id: build_id) }

    before do
      Fog.mock!
      Fog::Mock.reset
      fog_storage.directories.create(key: bucket_name) if bucket_name
      ENV.stub(to_hash: {
        'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake access key',
        'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake secret key',
      })
    end

    its(:gems_dir_url) { should eq('https://s3.amazonaws.com/bosh-ci-pipeline/456/gems/') }

    describe '#initialize' do
      context 'when initialized without any dependencies' do
        subject(:pipeline) { Pipeline.new }

        before do
          Build.stub(candidate: instance_double('Build', number: '102948923'))
        end

        it 'uses a default logger to stdout' do
          Logger.should_receive(:new).with($stdout)
          pipeline
        end
      end
    end

    describe '#upload_r' do
      let(:src) { 'source_dir' }
      let(:dst) { 'dest_dir' }
      let(:files) { %w(foo/bar.txt foo/bar/baz.txt) }

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
        pipeline.should_receive(:create).with do |options|
          expect(options[:public]).to eq(true)

          case options[:key]
            when 'dest_dir/foo/bar.txt'
              expect(options[:body].read).to eq('Contents of foo/bar.txt')
            when 'dest_dir/foo/bar/baz.txt'
              expect(options[:body].read).to eq('Contents of foo/bar/baz.txt')
            else
              raise "unexpected key: #{options[:key]}"
          end
        end.exactly(2).times

        subject.upload_r(src, dst)
      end
    end

    describe '#publish_stemcell' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

      before do
        FileUtils.mkdir('/tmp')
        File.open(stemcell.path, 'w') { |f| f.write(stemcell_contents) }
        logger.stub(:info)
      end

      describe 'when publishing a full stemcell' do
        let(:stemcell_contents) { 'contents of the stemcells' }
        let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a stemcell to an S3 bucket' do
          logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/456/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz')

          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/bosh-stemcell-aws-ubuntu.tgz').body).to eq 'contents of the stemcells'
        end

        it 'updates the latest stemcell in the S3 bucket' do
          logger.should_receive(:info).with('uploaded to s3://bosh-ci-pipeline/456/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz')

          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/bosh-stemcell-latest-aws-xen-ubuntu.tgz').body).to eq 'contents of the stemcells'
        end
      end

      describe 'when publishing a light stemcell' do
        let(:stemcell_contents) { 'this file is a light stemcell' }
        let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell', light?: true, path: '/tmp/light-bosh-stemcell-aws-ubuntu.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a light stemcell to S3 bucket' do
          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/light-bosh-stemcell-aws-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/light-bosh-stemcell-aws-ubuntu.tgz').body).to eq 'this file is a light stemcell'
        end

        it 'updates the latest light stemcell in the s3 bucket' do
          pipeline.publish_stemcell(stemcell)

          expect(bucket_files.map(&:key)).to include '456/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz'
          expect(bucket_files.get('456/bosh-stemcell/aws/light-bosh-stemcell-latest-aws-xen-ubuntu.tgz').body).to eq 'this file is a light stemcell'
        end
      end
    end

    describe '#cleanup_stemcells' do
      it 'removes stemcells created during the build' do
        FileUtils.mkdir_p(download_directory)
        FileUtils.touch(File.join(download_directory, 'foo-bosh-stemcell-bar-ubuntu.tgz'))
        FileUtils.touch(File.join(download_directory, 'foo-micro-bosh-stemcell-bar-ubuntu.tgz'))

        expect {
          subject.cleanup_stemcells(download_directory)
        }.to change { Dir.glob(File.join(download_directory, '*')) }.to([])
      end
    end
  end
end
