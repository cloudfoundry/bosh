require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::ReleasesToDeletePicker do
    subject(:releases_to_delete_picker) { Jobs::Helpers::ReleasesToDeletePicker.new(Api::ReleaseManager.new) }
    let(:release_1) { Models::Release.make(name: 'release-1') }
    let(:release_2) { Models::Release.make(name: 'release-2') }

    describe '#pick' do
      before do
        deployment_1 = Models::Deployment.make(name: 'first')
        deployment_2 = Models::Deployment.make(name: 'second')

        release_version_with_deployment_1 = Models::ReleaseVersion.make(version: 1, release: release_1)
        release_version_with_deployment_1.add_deployment(deployment_1)

        release_version_with_deployment_2 = Models::ReleaseVersion.make(version: 2, release: release_2)
        release_version_with_deployment_2.add_deployment(deployment_2)

        Models::ReleaseVersion.make(version: 5, release: release_2)
      end

      context 'when removing all releases' do
        it 'picks unused releases' do
          expect(releases_to_delete_picker.pick(0)).to match_array([
                {'name' => 'release-2', 'version' => '5'}
              ])
        end
      end

      context 'when removing all except the latest two releases' do
        before do
          Models::ReleaseVersion.make(version: 10, release: release_1)
          Models::ReleaseVersion.make(version: 9, release: release_1)
          Models::ReleaseVersion.make(version: 10, release: release_2)
          Models::ReleaseVersion.make(version: 9, release: release_2)
        end

        it 'leaves out the latest two versions of each release' do
          expect(releases_to_delete_picker.pick(2)).to match_array([
                {'name' => 'release-2', 'version' => '5'}
              ])
        end
      end
    end
  end
end
