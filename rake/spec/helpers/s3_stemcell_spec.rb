require 'spec_helper'
require 'fakefs/spec_helpers'
require_relative '../../lib/helpers/s3_stemcell'

module Bosh::Helpers
  describe S3Stemcell do
    include FakeFS::SpecHelpers

    subject do
      S3Stemcell.new('infrastructure', 'type')
    end

    describe '#publish' do
      before do
        Build.stub(candidate: double(number: 123))
      end

      it 'uploads the built stemcell to the pipeline bucket' do
        FileUtils.mkdir_p('/mnt/stemcells/infrastructure-type/work/work')
        FileUtils.touch('/mnt/stemcells/infrastructure-type/work/work/bosh-stemcell-infrastructure-123.tgz')

        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd put /mnt/stemcells/infrastructure-type/work/work/bosh-stemcell-infrastructure-123.tgz s3://bosh-ci-pipeline/stemcells/infrastructure/type/')
        subject.publish
      end

      context "when the stemcell isn't found" do
        it 'should really raise, but fails silently for now' do
          Rake::FileUtilsExt.should_not_receive(:sh)
          subject.publish
        end
      end
    end

    describe '#download_latest' do
      it 'downloads the latest stemcell from the pipeline bucket' do
        subject.stub(:`).and_return('version')

        Rake::FileUtilsExt.should_receive(:sh).with('s3cmd -f get s3://bosh-ci-pipeline/stemcells/infrastructure/type/bosh-stemcell-infrastructure-version.tgz')
        subject.download_latest
      end
    end
  end
end
