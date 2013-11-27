require 'spec_helper'
require 'bosh/dev/bosh_release_publisher'

describe Bosh::Dev::BoshReleasePublisher do
  let(:candidate_build) { instance_double('Bosh::Dev::Build', number: 1234) }
  let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }

  describe '.setup_for' do
    it 'instantiates a publisher with the given build and upload/download adapters' do
      Bosh::Dev::UploadAdapter.stub(:new).with(no_args).and_return(upload_adapter)

      publisher = double
      described_class.should_receive(:new).with(candidate_build, upload_adapter).and_return(publisher)
      described_class.setup_for(candidate_build).should eq(publisher)
    end
  end

  describe '#publish' do
    it 'uploads the build and then stages the changes' do
      Bosh::Dev::Build.stub(candidate: candidate_build)
      publisher = described_class.new(candidate_build, upload_adapter)

      release = double('bosh release')
      Bosh::Dev::BoshRelease.stub(:build).with(no_args).and_return(release)
      release_changes = instance_double('Bosh::Dev::ReleaseChangeStager')

      pwd = double('pwd')
      Dir.stub(:pwd).with(no_args).and_return(pwd)

      Bosh::Dev::ReleaseChangeStager.should_receive(:new).with(
        pwd,
        candidate_build.number,
        upload_adapter,
      ).and_return(release_changes)

      candidate_build.should_receive(:upload_release).ordered.with(release)
      release_changes.should_receive(:stage).ordered.with(no_args)

      publisher.publish
    end
  end
end
