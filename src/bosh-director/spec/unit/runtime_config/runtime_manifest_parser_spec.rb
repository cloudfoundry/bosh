require 'spec_helper'

module Bosh::Director
  describe RuntimeConfig::RuntimeManifestParser do
    subject(:parser) { described_class.new() }
    let(:planner_options) { {} }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:runtime_manifest) { Bosh::Spec::Deployments.simple_runtime_config }

      it "raises RuntimeInvalidReleaseVersion if a release uses version 'latest'" do
        runtime_manifest['releases'][0]['version'] = 'latest'
        expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
      end

      it "raises RuntimeInvalidReleaseVersion if a release uses relative version '.latest'" do
        runtime_manifest['releases'][0]['version'] = '3146.latest'
        expect { subject.parse(runtime_manifest) }.to raise_error(Bosh::Director::RuntimeInvalidReleaseVersion)
      end

      it "raises AddonReleaseNotListedInReleases if addon job's release is not listed in releases" do
        runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
        runtime_manifest['releases'][0]['name'] = 'weird_name'
        expect { subject.parse(runtime_manifest) }.to raise_error(AddonReleaseNotListedInReleases)
      end

      context 'when runtime manifest does not have an include or exclude section' do
        let(:runtime_manifest) { Bosh::Spec::Deployments.runtime_config_with_addon }

        it 'appends addon jobs to deployment job templates and addon properties to deployment job properties' do
          expect(Addon::Filter).to receive(:new).with([], [], [], :include)
          expect(Addon::Filter).to receive(:new).with([], [], [], :exclude)

          result = subject.parse(runtime_manifest)

          releases = result.releases
          expect(releases.count).to eq(1)
          expect(releases.first.name).to eq(runtime_manifest['releases'][0]['name'])
          expect(releases.first.version).to eq(runtime_manifest['releases'][0]['version'])

          expect(result.addons.count).to eq(1)
          addon = result.addons.first
          expect(addon.name).to eq('addon1')
          expect(addon.jobs).to eq([{'name' => 'dummy_with_properties', 'release' => 'dummy2', 'provides_links' => [], 'consumes_links' => [], 'properties' => nil},
            {'name' => 'dummy_with_package', 'release' => 'dummy2', 'provides_links' => [], 'consumes_links' => [], 'properties' => nil}])
          expect(addon.properties).to eq({'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}})
        end
      end

      context 'when runtime manifest has an include section' do
        let(:runtime_manifest) { Bosh::Spec::Deployments.runtime_config_with_addon }

        context 'when deployment name is in the includes.deployments section' do
          let(:runtime_manifest) do
            runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
            runtime_manifest['addons'].first.merge!(
                {
                  'include' => {
                    'deployments' => ['dep1']
                  }
                })
            runtime_manifest
          end

          it 'returns deployment associated with addon' do
            expect(Addon::Filter).to receive(:new).with([], ['dep1'], [], :include)
            expect(Addon::Filter).to receive(:new).with([], [], [], :exclude)

            subject.parse(runtime_manifest)
          end
        end
      end

      context 'when runtime manifest has an exclude section' do
        let(:runtime_manifest) { Bosh::Spec::Deployments.runtime_config_with_addon_excludes }

        context 'when deployment name is in the includes.deployments section' do
          let(:runtime_manifest) do
            runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
            runtime_manifest['addons'].first.merge!(
                {
                  'exclude' => {
                    'deployments' => ['dep1']
                  }
                })
            runtime_manifest
          end

          it 'returns deployment associated with addon' do
            expect(Addon::Filter).to receive(:new).with([], [], [], :include)
            expect(Addon::Filter).to receive(:new).with([], ['dep1'], [], :exclude)

            subject.parse(runtime_manifest)
          end
        end

        context 'when jobs section present' do
          context 'when only job name is provided' do
            let(:runtime_manifest) do
              runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
              runtime_manifest['addons'].first.merge!(
                  {
                    'exclude' => {
                      'jobs' => [{'name' => 'foobar'}]
                    }
                  })
              runtime_manifest
            end
            it 'throws an error' do
              expect { subject.parse(runtime_manifest) }.to raise_error(AddonIncompleteFilterJobSection)
            end
          end

          context 'when only release is provided' do
            let(:runtime_manifest) do
              runtime_manifest = Bosh::Spec::Deployments.runtime_config_with_addon
              runtime_manifest['addons'].first.merge!(
                  {
                    'exclude' => {
                      'jobs' => [{'release' => 'foobar'}]
                    }
                  })
              runtime_manifest
            end
            it 'throws an error' do
              expect { subject.parse(runtime_manifest) }.to raise_error(AddonIncompleteFilterJobSection)
            end
          end
        end
      end
    end
  end
end
