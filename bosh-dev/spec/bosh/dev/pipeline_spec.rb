require 'spec_helper'
require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'
require 'fakefs/spec_helpers'

module Bosh
  module Dev
    describe Pipeline do
      include FakeFS::SpecHelpers

      let(:fog_storage) { Fog::Storage.new(provider: 'AWS', aws_access_key_id: '...', aws_secret_access_key: '...') }
      let(:bucket_files) { fog_storage.directories.get('bosh-ci-pipeline').files }
      subject(:pipeline) { Pipeline.new(fog_storage: fog_storage) }

      before do
        Fog.mock!
        Fog::Mock.reset
        fog_storage.directories.create(key: 'bosh-ci-pipeline')
      end

      its(:bucket) { should eq('bosh-ci-pipeline') }

      describe '#s3_upload' do
        before do
          File.open('foobar-path', 'w') { |f| f.write('test data') }
        end

        it 'uploads the file to the specific path on the pipeline bucket' do
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
        end

        describe 'when publishing a full stemcell' do
          let(:stemcell_contents) { 'contents of the stemcells' }
          let(:stemcell) { instance_double('Stemcell', light?: false, path: '/tmp/bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

          it 'publishes a stemcell to an S3 bucket' do
            pipeline.publish_stemcell(stemcell)

            expect(bucket_files.map(&:key)).to include 'bosh-stemcell/aws/bosh-stemcell-aws.tgz'
            expect(bucket_files.get('bosh-stemcell/aws/bosh-stemcell-aws.tgz').body).to eq 'contents of the stemcells'
          end

          it 'updates the latest stemcell in the S3 bucket' do
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
          pipeline.download_stemcell('123', infrastructure: 'aws', name: 'bosh-stemcell', light: false)
          expect(File.read('bosh-stemcell-aws-123.tgz')).to eq 'this is a thinga-ma-jiggy'
        end

        it 'downloads the specified light stemcell version from the pipeline bucket' do
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
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: false)
          expect(File.read('latest-bosh-stemcell-aws.tgz')).to eq 'this is a thinga-ma-jiggy'
        end

        it 'downloads the latest light stemcell from the pipeline bucket' do
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
