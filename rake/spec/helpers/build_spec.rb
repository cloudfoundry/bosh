require 'spec_helper'
require_relative '../../lib/helpers/build'

module Bosh::Helpers
  describe Build do
    before do
      ENV.stub(:fetch).with('BUILD_NUMBER').and_return('current')
      ENV.stub(:fetch).with('CANDIDATE_BUILD_NUMBER').and_return('candidate')
      ENV.stub(:fetch).with('JOB_NAME').and_return('current_job')
    end

    describe '.current' do
      subject do
        Build.current
      end

      its(:s3_release_url) { should eq('s3://bosh-ci-pipeline/release/bosh-current.tgz') }
    end

    describe '.candidate' do
      subject do
        Build.candidate
      end

      its(:s3_release_url) { should eq('s3://bosh-ci-pipeline/release/bosh-candidate.tgz') }
    end

    describe '.job_name' do
      subject do
        Build.candidate
      end

      its(:job_name) { should eq('current_job') }
    end
  end
end
