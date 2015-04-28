require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::ManifestMigrator do
      subject { DeploymentPlan::ManifestMigrator.new }
      let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
      let(:migrated) { subject.migrate(manifest_hash) }

      describe '#migrate' do
        context 'when a "release" key is not found' do
          it 'retains the "releases" entry' do
            manifest_hash.delete('release')
            manifest_hash['releases'] = [{ some: :stuff }]
            expect(migrated['releases']).to eq([{ some: :stuff }])
          end
        end

        context 'when a "release" key is found' do
          it 'returns the unmutated values for most keys' do
            manifest_hash['name'] = 'my-custom-name'
            expect(migrated['name']).to eq('my-custom-name')
          end

          it 'migrates the legacy release key' do
            manifest_hash.delete('releases')
            manifest_hash['release'] = { some: :stuff }
            expect(migrated).to_not have_key('release')
            expect(migrated['releases']).to eq([{ some: :stuff }])
          end

          context 'and it has a nil value' do
            it 'migrates, resulting in an empty "releases" array' do
              manifest_hash.delete('releases')
              manifest_hash['release'] = nil
              expect(migrated).to_not have_key('release')
              expect(migrated['releases']).to eq([])
            end
          end

          it 'blows up if both release and releases keys are present' do
            manifest_hash['release'] = {some: :stuff}
            manifest_hash['releases'] = [{other: :stuff}]

            expect {
              subject.migrate(manifest_hash)
            }.to raise_error(
              DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' sections, please use one of the two."
            )
          end
        end
      end
    end
  end
end
