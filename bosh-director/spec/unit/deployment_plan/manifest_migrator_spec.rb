require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::ManifestMigrator do
      subject { DeploymentPlan::ManifestMigrator.new }
      let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
      let(:cloud_config) { nil }
      let(:migrated_manifest) { subject.migrate(manifest_hash, cloud_config)[0] }
      let(:migrated_cloud_config) { subject.migrate(manifest_hash, cloud_config)[1] }

      describe '#migrate' do
        context 'when a "release" key is not found' do
          it 'retains the "releases" entry' do
            manifest_hash.delete('release')
            manifest_hash['releases'] = [{ some: :stuff }]
            expect(migrated_manifest['releases']).to eq([{ some: :stuff }])
          end
        end

        context 'when a "release" key is found' do
          it 'returns the unmutated values for most keys' do
            manifest_hash['name'] = 'my-custom-name'
            expect(migrated_manifest['name']).to eq('my-custom-name')
          end

          it 'migrates the legacy release key' do
            manifest_hash.delete('releases')
            manifest_hash['release'] = { some: :stuff }
            expect(migrated_manifest).to_not have_key('release')
            expect(migrated_manifest['releases']).to eq([{ some: :stuff }])
          end

          context 'and it has a nil value' do
            it 'migrates, resulting in an empty "releases" array' do
              manifest_hash.delete('releases')
              manifest_hash['release'] = nil
              expect(migrated_manifest).to_not have_key('release')
              expect(migrated_manifest['releases']).to eq([])
            end
          end

          it 'blows up if both release and releases keys are present' do
            manifest_hash['release'] = {some: :stuff}
            manifest_hash['releases'] = [{other: :stuff}]

            expect {
              subject.migrate(manifest_hash, cloud_config)
            }.to raise_error(
              DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' sections, please use one of the two."
            )
          end
        end

        describe 'cloud_config' do
          context 'when cloud config is not set' do
            let(:manifest_hash) do
              {
                'resource_pools' => ['fake-resource-pool'],
                'compilation' => ['fake-compilation'],
                'disk_pools' => ['fake-disk-pools'],
                'networks' => ['fake-networks']
              }
            end

            it 'constructs cloud config from deployment manifest' do
              expect(migrated_cloud_config['resource_pools']).to eq(['fake-resource-pool'])
              expect(migrated_cloud_config['compilation']).to eq(['fake-compilation'])
              expect(migrated_cloud_config['disk_pools']).to eq(['fake-disk-pools'])
              expect(migrated_cloud_config['networks']).to eq(['fake-networks'])
            end
          end

          context 'when cloud config is set' do
            let(:cloud_config) { double(:cloud_config, manifest: 'fake-cloud-config') }

            it 'returns passed cloud config' do
              expect(migrated_cloud_config).to eq('fake-cloud-config')
            end

            context 'when deployment manifest contains properties from cloud config' do
              let(:manifest_hash) do
                {
                  'resource_pools' => ['fake-resource-pool'],
                  'compilation' => ['fake-compilation'],
                }
              end

              it 'raises invalid property error' do
                expect {
                  subject.migrate(manifest_hash, cloud_config)
                }.to raise_error(
                    DeploymentInvalidProperty,
                    'Deployment manifest should not contain cloud config properties: ["resource_pools", "compilation"]'
                )
              end
            end
          end
        end
      end
    end
  end
end
