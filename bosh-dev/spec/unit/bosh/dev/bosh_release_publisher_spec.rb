require 'spec_helper'
require 'bosh/dev/bosh_release_publisher'

describe Bosh::Dev::BoshReleasePublisher do
  let(:candidate_build) { instance_double('Bosh::Dev::Build', number: 1234) }
  let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }

  describe '.setup_for' do
    it 'instantiates a publisher with the given build and upload/download adapters' do
      allow(Bosh::Dev::UploadAdapter).to receive(:new).with(no_args).and_return(upload_adapter)

      publisher = double
      expect(described_class).to receive(:new).with(candidate_build, upload_adapter).and_return(publisher)
      expect(described_class.setup_for(candidate_build)).to eq(publisher)
    end
  end

  describe '#publish' do
    it 'uploads the build and then stages the changes' do
      allow(Bosh::Dev::Build).to receive_messages(candidate: candidate_build)
      publisher = described_class.new(candidate_build, upload_adapter)

      release = double('bosh release')
      allow(Bosh::Dev::BoshRelease).to receive(:build).with(no_args).and_return(release)
      release_changes = instance_double('Bosh::Dev::ReleaseChangeStager')

      pwd = double('pwd')
      allow(Dir).to receive(:pwd).with(no_args).and_return(pwd)

      expect(Bosh::Dev::ReleaseChangeStager).to receive(:new).with(
        pwd,
        candidate_build.number,
        upload_adapter,
      ).and_return(release_changes)

      expect(candidate_build).to receive(:upload_release).ordered.with(release)
      expect(release_changes).to receive(:stage).ordered.with(no_args)

      publisher.publish
    end
  end
end
