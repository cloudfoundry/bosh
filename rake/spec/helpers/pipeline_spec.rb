require 'spec_helper'
require_relative '../../lib/helpers/pipeline'
require_relative '../../lib/helpers/stemcell'

module Bosh
  module Helpers
    describe Pipeline do
      subject(:pipeline) { Pipeline.new }

      it 'publishes a stemcell to S3 bucket' do
        stemcell = double(Stemcell, is_light?: false, path: '/tmp/bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell')

        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /tmp/bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws.tgz')
        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd cp --force s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz')

        pipeline.publish_stemcell(stemcell)
      end

      it 'publishes a light stemcell to S3 bucket' do
        stemcell = double(Stemcell, is_light?: true, path: '/tmp/light-bosh-stemcell-aws.tgz', infrastructure: 'aws', name: 'bosh-stemcell')

        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /tmp/light-bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws.tgz')
        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd cp --force s3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws.tgz s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz')

        pipeline.publish_stemcell(stemcell)
      end

      describe 'download_latest_stemcell' do

        it 'downloads the latest stemcell from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-bosh-stemcell-aws.tgz')
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell')
        end

        it 'downloads the latest light stemcell from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/latest-light-bosh-stemcell-aws.tgz')
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: true)
        end
      end
    end
  end
end