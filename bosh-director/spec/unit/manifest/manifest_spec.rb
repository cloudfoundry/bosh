require 'spec_helper'

module Bosh::Director
  describe Manifest do
    subject(:manifest) { described_class.new(manifest_hash, cloud_config_hash, runtime_config_hash) }
    let(:manifest_hash) { {} }
    let(:cloud_config_hash) { {} }
    let(:runtime_config_hash) { {} }

    before do
      release_1 = Models::Release.make(name: 'simple')
      Models::ReleaseVersion.make(version: 6, release: release_1)
      Models::ReleaseVersion.make(version: 9, release: release_1)

      release_1 = Models::Release.make(name: 'hard')
      Models::ReleaseVersion.make(version: '1+dev.5', release: release_1)
      Models::ReleaseVersion.make(version: '1+dev.7', release: release_1)

      Models::Stemcell.make(name: 'simple', version: '3163')
      Models::Stemcell.make(name: 'simple', version: '3169')

      Models::Stemcell.make(name: 'hard', version: '3146')
      Models::Stemcell.make(name: 'hard', version: '3146.1')
    end

    describe 'resolve_aliases' do
      context 'when manifest has releases with version latest' do
        let(:manifest_hash) do
          {
            'releases' => [
              {'name' => 'simple', 'version' => 'latest'},
              {'name' => 'hard', 'version' => 'latest'}
            ]
          }
        end

        it 'replaces latest with the latest version number' do
          manifest.resolve_aliases
          expect(manifest.to_hash['releases']).to eq([
            {'name' => 'simple', 'version' => '9'},
            {'name' => 'hard', 'version' => '1+dev.7'}
          ])
        end
      end

      context 'when manifest has no alias' do
        let(:manifest_hash) do
          {
            'releases' => [
              {'name' => 'simple', 'version' => 9},
              {'name' => 'hard', 'version' => '42'}
            ]
          }
        end

        it 'leaves it as it is and converts to string' do
          manifest.resolve_aliases
          expect(manifest.to_hash['releases']).to eq([
           {'name' => 'simple', 'version' => '9'},
           {'name' => 'hard', 'version' => '42'}
          ])
        end
      end

      context 'when manifest has stemcells with version latest' do
        let(:manifest_hash) do
          {
            'stemcells' => [
              {'name' => 'simple', 'version' => 'latest'},
              {'name' => 'hard', 'version' => 'latest'}
            ]
          }
        end

        it 'replaces latest with the latest version number' do
          manifest.resolve_aliases
          expect(manifest.to_hash['stemcells']).to eq([
            {'name' => 'simple', 'version' => '3169'},
            {'name' => 'hard', 'version' => '3146.1'}
          ])
        end
      end

      context 'when manifest has stemcell with no alias' do
        let(:manifest_hash) do
          {
            'stemcells' => [
              {'name' => 'simple', 'version' => 42},
              {'name' => 'hard', 'version' => 'latest'}
            ]
          }
        end

        it 'leaves it as it is and converts to string' do
          manifest.resolve_aliases
          expect(manifest.to_hash['stemcells']).to eq([
            {'name' => 'simple', 'version' => '42'},
            {'name' => 'hard', 'version' => '3146.1'}
          ])
        end
      end

      context 'when cloud config has stemcells with version latest' do
        let(:cloud_config_hash) do
          {
            'resource_pools' => [
              {
                'name' => 'rp1',
                'stemcell' => { 'name' => 'simple', 'version' => 'latest'}
              }
            ]
          }
        end

        it 'replaces latest with the latest version number' do
          manifest.resolve_aliases
          expect(manifest.to_hash['resource_pools'].first['stemcell']).to eq(
            { 'name' => 'simple', 'version' => '3169'}
          )
        end
      end
    end

    describe '#diff' do
      subject(:new_manifest) { described_class.new(new_manifest_hash, new_cloud_config_hash, new_runtime_config_hash) }
      let(:new_manifest_hash) do
        {
          'jobs' => [
            {
              'name' => 'useful',
              'properties' => {
                'inner' => 'secrets',
              },
            },
          ],
          'properties' => {
            'something' => 'worth-redacting',
          },
        }
      end
      let(:new_cloud_config_hash) { cloud_config_hash }
      let(:new_runtime_config_hash) { runtime_config_hash }
      let(:diff) do
        manifest.diff(new_manifest, redact).map(&:text).join("\n")
      end

      context 'when redact is true' do
        let(:redact) { true }

        it 'redacts properties' do
          expect(diff).to include('<redacted>')
        end
      end

      context 'when redact is false' do
        let(:redact) { false }

        it 'doesn\'t redact properties' do
          expect(diff).to_not include('<redacted>')
        end
      end
    end

    describe 'to_hash' do
      context 'when runtime config contains same release/version as deployment manifest' do
        let(:manifest_hash) do
          {
              'releases' => [
                  {'name' => 'simple', 'version' => '2'},
                  {'name' => 'hard', 'version' => 'latest'}
              ]
          }
        end

        let(:runtime_config_hash) do
          {
              'releases' => [
                  {'name' => 'simple', 'version' => '2'}
              ]
          }
        end

        it 'includes only one copy of the release in to_hash output' do
          expect(manifest.to_hash['releases']).to eq([
               {'name' => 'simple', 'version' => '2'},
               {'name' => 'hard', 'version' => 'latest'}
           ])
        end
      end
    end
  end
end
