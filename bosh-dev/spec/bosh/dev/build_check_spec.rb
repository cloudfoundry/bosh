require 'spec_helper'
require 'bosh/dev/build_check'

module Bosh::Dev
  describe BuildCheck do
    let(:jenkins_client) { instance_double('JenkinsApi::Client') }
    let(:color) { 'tartan' }
    let(:build_name) { 'build_name' }
    let(:job_details) { { 'color' => color } }

    subject(:build_check) { BuildCheck.new(jenkins_client, build_name) }

    before do
      job = instance_double('JenkinsApi::Client::Job')
      job.stub(:list_details).with(build_name).and_return(job_details)
      jenkins_client.stub(job: job)
    end

    describe '#failing?' do
      context 'when the build color is red' do
        let(:color) { 'red' }

        it { should be_failing }
      end

      context 'when the build color is red_anime' do
        let(:color) { 'red_anime' }

        it { should be_failing }
      end

      context 'when the build color is not red' do
        let(:color) { 'blue_anime' }

        it { should_not be_failing }
      end
    end
  end
end
