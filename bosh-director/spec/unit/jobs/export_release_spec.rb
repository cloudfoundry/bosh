require 'spec_helper'

module Bosh::Director
  describe Jobs::ExportRelease do
    let(:snapshots) { [Models::Snapshot.make(snapshot_cid: 'snap0'), Models::Snapshot.make(snapshot_cid: 'snap1')] }

    subject(:job) { described_class.new("deployment_name", "release_name", "release_version", "stemcell_os", "stemcell_version") }

    context 'when the requested release does not exist' do
      it 'fails with the expected error' do
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseNotFound)
      end
    end

    context 'when the requested release exists but release version does not exist' do
      before { Bosh::Director::Models::Release.create(name: 'release_name') }

      it 'fails with the expected error' do
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseVersionNotFound)
      end
    end

    context 'when the requested release and version exist' do
      before {
        release = Bosh::Director::Models::Release.create(name: 'release_name')
        release.add_version(:version => 'release_version')
      }
      it 'succeeds' do
        expect {
          job.perform
        }.to_not raise_error
      end
    end
  end
end