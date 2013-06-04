require 'spec_helper'
require_relative '../../lib/helpers/pipeline'

module Bosh
  module Helpers
    describe Pipeline do
      subject(:pipeline) { Pipeline.new('aws', 'basic') }

      it 'publishes given path to S3 stemcell bucket' do
        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /path/to/fake.tgz s3://bosh-ci-pipeline/stemcells/aws/basic/')

        pipeline.publish('/path/to/fake.tgz')
      end
    end
  end
end