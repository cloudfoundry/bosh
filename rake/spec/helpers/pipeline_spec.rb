require 'spec_helper'
require_relative '../../lib/helpers/pipeline'
require_relative '../../lib/helpers/stemcell'

module Bosh
  module Helpers
    describe Pipeline do
      subject(:pipeline) { Pipeline.new }

      it 'publishes given path to S3 stemcell bucket' do
        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /path/to/fake.tgz s3://bosh-ci-pipeline/micro-bosh-stemcell/aws/')

        pipeline.publish('/path/to/fake.tgz', 'micro-bosh-stemcell/aws/')
      end

      it 'publishes a stemcell to S3 bucket' do
        stemcell = double(Stemcell, path: '/tmp/stemcell.tgz', infrastructure: 'aws', name: 'bosh-stemcell')

        pipeline.should_receive(:publish).with('/tmp/stemcell.tgz', 'bosh-stemcell/aws/stemcell.tgz')
        pipeline.publish_stemcell(stemcell)
      end

      describe 'download_latest_stemcell' do
        before do
          pipeline.stub(:`).and_return('123')
          FileUtils.stub(:ln_s)
        end

        it 'downloads the latest stemcell from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/bosh-stemcell-aws-123.tgz')
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell')
        end

        it 'downloads the latest light stemcell from the pipeline bucket' do
          Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/bosh-stemcell/aws/light-bosh-stemcell-aws-123.tgz')
          pipeline.download_latest_stemcell(infrastructure: 'aws', name: 'bosh-stemcell', light: true)
        end
      end
    end
  end
end