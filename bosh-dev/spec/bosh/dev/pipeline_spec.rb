require 'spec_helper'
require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'
require 'fakefs/spec_helpers'

module Bosh
  module Dev
    describe Pipeline do
      include FakeFS::SpecHelpers

      let(:fog_storage) { Fog::Storage.new(provider: 'AWS', aws_access_key_id: 'fake access key', aws_secret_access_key: 'fake secret key') }
      let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }
      let(:bucket_name) { 'bosh-ci-pipeline' }
      let(:logger) { instance_double('Logger') }
      subject(:pipeline) { Pipeline.new(fog_storage: fog_storage, logger: logger) }

      before do
        Fog.mock!
        Fog::Mock.reset
        fog_storage.directories.create(key: bucket_name) if bucket_name
      end

      its(:bucket) { should eq('bosh-ci-pipeline') }
      its(:gems_dir_url) { should eq('https://s3.amazonaws.com/bosh-ci-pipeline/gems/') }

      describe '#create' do
        let(:bucket) { fog_storage.directories.get(bucket_name) }

        it 'creates the specified file on the pipeline bucket' do
          pipeline.create(key: 'dest_dir/foo/bar/baz.txt', body: 'contents of baz', public: true)

          expect(bucket.files.get('dest_dir/foo/bar/baz.txt')).not_to be_nil
          expect(bucket.files.get('dest_dir/foo/bar/baz.txt').body).to eq('contents of baz')
          expect(bucket.files.get('dest_dir/foo/bar/baz.txt').public_url).not_to be_nil
        end

        it 'publicizes the bucket only when asked to' do
          pipeline.create(key: 'dest_dir/foo/bar/baz.txt', body: 'contents of baz', public: false)

          expect(bucket.files.get('dest_dir/foo/bar/baz.txt').public_url).to be_nil
        end

        context 'when the bucket does not exist' do
          let(:bucket_name) { false }

          it 'raises an error' do
            expect {
              pipeline.create({})
            }.to raise_error("bucket 'bosh-ci-pipeline' not found")
          end
        end
      end

      describe '#fog_storage' do
        subject(:pipeline) do
          Pipeline.new(logger: logger)
        end

        before do
          ENV.stub(:to_hash).and_return({
                                            'AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake access key',
                                            'AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT' => 'fake secret key',
                                        })
        end

        it 'uses the aws access key and secret key configured in Jenkins' do
          expect(pipeline.fog_storage).not_to be_nil
          expect(pipeline.fog_storage.instance_variable_get(:@aws_access_key_id)).to eq('fake access key')
          expect(pipeline.fog_storage.instance_variable_get(:@aws_secret_access_key)).to eq('fake secret key')
        end
      end

      describe '#s3_upload' do
        before do
          File.open('foobar-path', 'w') { |f| f.write('test data') }
        end

        it 'uploads the file to the specific path on the pipeline bucket' do
          logger.should_receive(:info).with("uploaded 'foobar-path' -> s3://bosh-ci-pipeline/foo-bar.tgz")

          pipeline.s3_upload('foobar-path', 'foo-bar.tgz')
          expect(bucket_files.map(&:key)).to include 'foo-bar.tgz'
          expect(bucket_files.get('foo-bar.tgz').body).to eq 'test data'
        end
      end

      describe '#publish_stemcell' do
        let(:stemcell) { double(Stemcell, light?: false, path: '/tmp/bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        before do
          FileUtils.mkdir('/tmp')
          File.open(stemcell.path, 'w') { |f| f.write(stemcell_contents) }
          logger.stub(:info)
        end

        describe 'when publishing a full stemcell' do
          let(:stemcell_contents) { 'contents of the stemcells' }
          let(:stemcell) { instance_double('Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

          it 'publishes a stemcell to an S3 bucket' do
            logger.should_receive(:info).with("uploaded '/tmp/bosh-stemcell-aws.tgz' -> s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws.tgz")

            pipeline.publish_stemcell(stemcell)

            expect(bucket_files.map(&:key)).to include 'bosh-stemcell/aws/bosh-stemcell-aws.tgz'
            expect(bucket_files.get('bosh-stemcell/aws/bosh-stemcell-aws.tgz').body).to eq 'contents of the stemcells'
          end

          it 'updates the latest stemcell in the S3 bucket' do
            logger.should_receive(:info).with("uploaded '/tmp/bosh-stemcell-aws.tgz' -> s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz")

            pipeline.publish_stemcell(stemcell)

            expect(bucket_files.map(&:key)).to include 'bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz'
            expect(bucket_files.get('bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz').body).to eq 'contents of the stemcells'
          end
        end

        describe 'when publishing a light stemcell' do
          let(:stemcell_contents) { 'this file is a light stemcell' }
          let(:stemcell) { instance_double('Stemcell', light?: true, path: '/tmp/light-bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

          it 'publishes a light stemcell to S3 bucket' do
            pipeline.publish_stemcell(stemcell)

            expect(bucket_files.map(&:key)).to include 'bosh-stemcell/aws/light-bosh-stemcell-aws.tgz'
            expect(bucket_files.get('bosh-stemcell/aws/light-bosh-stemcell-aws.tgz').body).to eq 'this file is a light stemcell'
          end

          it 'updates the latest light stemcell in the s3 bucket' do
            pipeline.publish_stemcell(stemcell)

            expect(bucket_files.map(&:key)).to include 'bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz'
            expect(bucket_files.get('bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz').body).to eq 'this file is a light stemcell'
          end
        end
      end

      describe '#download_stemcell' do

        before do
          bucket_files.create(key: 'bosh-stemcell/aws/bosh-stemcell-aws-123.tgz', body: 'this is a thinga-ma-jiggy')
          bucket_files.create(key: 'bosh-stemcell/aws/light-bosh-stemcell-aws-123.tgz', body: 'this a completely different thingy')
        end

        it 'downloads the specified stemcell version from the pipeline bucket' do
          logger.should_receive(:info).with("downloaded 's3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws-123.tgz' -> 'bosh-stemcell-aws-123.tgz'")

          pipeline.download_stemcell('123', infrastructure: 'aws', name: 'bosh-stemcell', light: false)
          expect(File.read('bosh-stemcell-aws-123.tgz')).to eq 'this is a thinga-ma-jiggy'
        end

        it 'downloads the specified light stemcell version from the pipeline bucket' do
          logger.should_receive(:info).with("downloaded 's3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws-123.tgz' -> 'light-bosh-stemcell-aws-123.tgz'")

          pipeline.download_stemcell('123', infrastructure: 'aws', name: 'bosh-stemcell', light: true)
          expect(File.read('light-bosh-stemcell-aws-123.tgz')).to eq 'this a completely different thingy'
        end
      end

      describe '#download_latest_stemcell' do
        before do
          bucket_files.create(key: 'bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz', body: 'this is a thinga-ma-jiggy')
          bucket_files.create(key: 'bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz', body: 'this a completely different thingy')
        end

        it 'downloads the latest stemcell from the pipeline bucket' do
          logger.should_receive(:info).with("downloaded 's3://bosh-ci-pipeline/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz' -> 'latest-bosh-stemcell-aws.tgz'")

          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: false)
          expect(File.read('latest-bosh-stemcell-aws.tgz')).to eq 'this is a thinga-ma-jiggy'
        end

        it 'downloads the latest light stemcell from the pipeline bucket' do
          logger.should_receive(:info).with("downloaded 's3://bosh-ci-pipeline/bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz' -> 'latest-light-bosh-stemcell-aws.tgz'")


          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: true)
          expect(File.read('latest-light-bosh-stemcell-aws.tgz')).to eq 'this a completely different thingy'
        end
      end

      describe '#latest_stemcell_filename' do
        it 'generates the latest stemcell filename' do
          expect(pipeline.latest_stemcell_filename('aws', 'bosh-stemcell', false)).to eq('latest-bosh-stemcell-aws.tgz')
        end

        it 'generates the latest light stemcell filename' do
          expect(pipeline.latest_stemcell_filename('aws', 'bosh-stemcell', true)).to eq('latest-light-bosh-stemcell-aws.tgz')
        end
      end
    end
  end
end
