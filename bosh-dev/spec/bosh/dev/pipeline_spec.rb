require 'spec_helper'
require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'

module Bosh
  module Dev
    describe Pipeline do
      subject(:pipeline) { Pipeline.new }

      its(:bucket) { should eq('bosh-ci-pipeline') }

      describe '#s3_upload' do
        it 'uploads the file to the specific path on the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put foobar s3://bosh-ci-pipeline/foobar-path')
          pipeline.s3_upload('foobar', 'foobar-path')
        end
      end

      describe '#publish_stemcell' do
        let(:stemcell) { double(Stemcell, is_light?: false, path: '/tmp/bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell') }

        it 'publishes a stemcell to S3 bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /tmp/bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws.tgz')
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd cp --force s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz')

          pipeline.publish_stemcell(stemcell)
        end

        it 'publishes a light stemcell to S3 bucket' do
          stemcell.stub(is_light?: true, path: '/tmp/light-bosh-stemcell-aws.tgz',)

          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /tmp/light-bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws.tgz')
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd cp --force s3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz')

          pipeline.publish_stemcell(stemcell)
        end
      end

      describe '#download_stemcell' do
        it 'downloads the specified stemcell version from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws-123.tgz')

          pipeline.download_stemcell('123', infrastructure: 'aws', name: 'bosh-stemcell', light: false)
        end

        it 'downloads the specified light stemcell version from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws-123.tgz')

          pipeline.download_stemcell('123', infrastructure: 'aws', name: 'bosh-stemcell', light: true)
        end
      end

      describe '#download_latest_stemcell' do
        it 'downloads the latest stemcell from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz')
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: false)
        end

        it 'downloads the latest light stemcell from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz')
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: true)
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
