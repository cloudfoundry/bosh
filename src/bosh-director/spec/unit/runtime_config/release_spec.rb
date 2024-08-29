require 'spec_helper'

module Bosh::Director
  module RuntimeConfig
    describe Release do
      subject(:release) { Release.parse(release_hash) }
      let(:version) { '42' }
      let(:release_hash) do
        {
          'name' => 'release-name',
          'version' => version
        }
      end

      describe '#parse' do
        it 'parses' do
          expect(release.name).to eq('release-name')
          expect(release.version).to eq('42')
        end

        context 'when the version is a number' do
          let(:version) { 66 }

          it 'converts safely to string' do
            expect(release.version).to eq('66')
          end
        end

        context 'when release hash has no name' do
          let(:release_hash) do
            { 'version' => '42' }
          end

          it 'errors' do
            expect { release }.to raise_error ValidationMissingField, "Required property 'name' was not specified in object ({\"version\"=>\"42\"})"
          end
        end

        context 'when release hash has no version' do
          let(:release_hash) do
            { 'name' => 'blarg' }
          end

          it 'errors' do
            expect { release }.to raise_error ValidationMissingField, "Required property 'version' was not specified in object ({\"name\"=>\"blarg\"})"
          end
        end

        context 'when version latest is used' do
          context 'latest' do
            let(:version) { 'latest' }

            it 'raises' do
              expect { release }.to raise_error RuntimeInvalidReleaseVersion, "Runtime manifest contains the release 'release-name' with version as 'latest'. " +
                'Please specify the actual version string.'
            end
          end

          context 'latest' do
            let(:version) { '42.latest' }

            it 'raises' do
              expect { release }.to raise_error RuntimeInvalidReleaseVersion, "Runtime manifest contains the release 'release-name' with version as '42.latest'. " +
                'Please specify the actual version string.'
            end
          end
        end
      end

      describe '#add_to_deployment' do
        let(:deployment) { instance_double(DeploymentPlan::Planner) }
        let(:deployment_model) { FactoryBot.create(:models_deployment) }
        let(:new_release_version) { instance_double(DeploymentPlan::ReleaseVersion) }

        context 'when the deployment already has the release' do
          before { expect(deployment).to receive(:release).with('release-name').and_return(release_version) }

          context 'when the release version matches the pre-existing release' do
            let(:release_version) { DeploymentPlan::ReleaseVersion.parse(deployment_model, release_hash) }

            it 'does nothing' do
              release.add_to_deployment(deployment)
            end
          end

          context 'when the release version is different from the pre-existing release version' do
            let(:release_version) do
              DeploymentPlan::ReleaseVersion.parse(deployment_model, 'name' => 'release-name', 'version' => '0')
            end

            it 'raises' do
              expect { release.add_to_deployment(deployment) }.to raise_error RuntimeInvalidDeploymentRelease,
                "Runtime manifest specifies release 'release-name' with version as '42'. This conflicts with version '0' specified in the deployment manifest."
            end
          end
        end

        context 'when the deployment does not have the release' do
          it 'creates a new release version and adds it to the deployment' do
            expect(deployment).to receive(:release).with('release-name').and_return(nil)
            expect(deployment).to receive(:model).and_return(deployment_model)
            expect(DeploymentPlan::ReleaseVersion).to receive(:new)
              .with(deployment_model, 'release-name', '42', [])
              .and_return(new_release_version)
            expect(new_release_version).to receive(:bind_model)
            expect(deployment).to receive(:add_release).with(new_release_version)
            release.add_to_deployment(deployment)
          end
        end
      end
    end
  end
end
