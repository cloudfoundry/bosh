require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::ReleasesToDeletePicker do
    subject(:releases_to_delete_picker) { Jobs::Helpers::ReleasesToDeletePicker.new(Api::ReleaseManager.new) }
    let(:release1) { FactoryBot.create(:models_release, name: 'release-1') }
    let(:release2) { FactoryBot.create(:models_release, name: 'release-2') }

    describe '#pick' do
      before do
        deployment1 = FactoryBot.create(:models_deployment, name: 'first')
        deployment2 = FactoryBot.create(:models_deployment, name: 'second')

        release_version_with_deployment1 = FactoryBot.create(:models_release_version, version: 1, release: release1)
        release_version_with_deployment1.add_deployment(deployment1)

        release_version_with_deployment2 = FactoryBot.create(:models_release_version, version: 2, release: release2)
        release_version_with_deployment2.add_deployment(deployment2)

        FactoryBot.create(:models_release_version, version: 5, release: release2)
      end

      context 'when removing all releases' do
        it 'picks unused releases' do
          expect(releases_to_delete_picker.pick(0)).to match_array(
            [
              { 'name' => 'release-2', 'versions' => ['5'] },
            ],
          )
        end
      end

      context 'when removing all except the latest two releases' do
        before do
          FactoryBot.create(:models_release_version, version: 10, release: release1)
          FactoryBot.create(:models_release_version, version: 9, release: release1)
          FactoryBot.create(:models_release_version, version: 10, release: release2)
          FactoryBot.create(:models_release_version, version: 9, release: release2)
        end

        it 'leaves out the latest two versions of each release' do
          expect(releases_to_delete_picker.pick(2)).to match_array(
            [
              { 'name' => 'release-2', 'versions' => ['5'] },
            ],
          )
        end
      end

      context 'when removing multiple versions' do
        before do
          FactoryBot.create(:models_release_version, version: 10, release: release1)
          FactoryBot.create(:models_release_version, version: 9, release: release1)
          FactoryBot.create(:models_release_version, version: 8, release: release1)
        end

        it 'leaves out the latest two versions of each release' do
          expect(releases_to_delete_picker.pick(1)).to match_array(
            [
              { 'name' => 'release-1', 'versions' => %w[8 9] },
            ],
          )
        end
      end

      context 'when releases are present in a runtime config' do
        let(:runtime_parser) { instance_double(RuntimeConfig::RuntimeManifestParser) }
        let(:runtime_config_release) { RuntimeConfig::Release.new(release1.name, 10, {}) }
        let(:runtime_config) { RuntimeConfig::ParsedRuntimeConfig.new([runtime_config_release], [], []) }

        before do
          FactoryBot.create(:models_release_version, version: 10, release: release1)
          FactoryBot.create(:models_release_version, version: 9, release: release1)
          FactoryBot.create(:models_release_version, version: 8, release: release1)
          Models::Config.make(type: 'runtime', name: 'jim')

          allow(RuntimeConfig::RuntimeManifestParser).to receive(:new).and_return(runtime_parser)
          allow(runtime_parser).to receive(:parse).and_return(runtime_config)
        end

        it 'does not delete the release version' do
          expect(releases_to_delete_picker.pick(0)).to match_array(
            [
              { 'name' => 'release-1', 'versions' => %w[8 9] },
              { 'name' => 'release-2', 'versions' => %w[5] },
            ],
          )
        end

        context 'when the release specified in the runtime config does not exist' do
          let(:runtime_config_release) { RuntimeConfig::Release.new('bogus-town', 100, {}) }
          let(:runtime_config) { RuntimeConfig::ParsedRuntimeConfig.new([runtime_config_release], [], []) }

          it 'does not delete the release version' do
            expect(releases_to_delete_picker.pick(0)).to match_array(
              [
                { 'name' => 'release-1', 'versions' => %w[8 9 10] },
                { 'name' => 'release-2', 'versions' => %w[5] },
              ],
            )
          end
        end
      end
    end
  end
end
