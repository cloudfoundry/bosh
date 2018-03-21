require 'spec_helper'

module Bosh::Director
  module Addon
    describe Parser do
      subject(:parser) { described_class.new(releases, manifest) }
      let(:manifest) {
        {
          'addons' => [
            {
              'name' => 'addon1',
              'jobs' => [{'name' => 'dummy_with_properties', 'release' => 'dummy2'}, {'name' => 'dummy_with_package', 'release' => 'dummy2'}],
              'properties' => {'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}}
            }]
        }
      }
      let(:releases) { [RuntimeConfig::Release.parse(release_hash)] }
      let(:release_hash) do
        {
          'name' => 'dummy2',
          'version' => '0.2-dev'
        }
      end

      describe '#parse' do
        context 'when no release in release section' do
          let(:releases) { [] }
          it 'returns an error' do
            expect { parser.parse() }.to raise_error(Bosh::Director::AddonReleaseNotListedInReleases,
              "Manifest specifies job 'dummy_with_properties' which is defined in 'dummy2', but 'dummy2' is not listed in the runtime releases section.")
          end
        end

        it 'parses manifest addon section to create addon object' do
          expect(Bosh::Director::Addon::Filter).to receive(:new).with([], [], [], [], [], [], '', :include)
          expect(Bosh::Director::Addon::Filter).to receive(:new).with([], [], [], [], [], [], '', :exclude)

          result = parser.parse()

          expect(result.count).to eq(1)
          addon = result.first
          expect(addon.name).to eq('addon1')
          expect(addon.jobs).to eq([{'name' => 'dummy_with_properties', 'release' => 'dummy2', 'provides_links' => [], 'consumes_links' => [], 'properties' => nil},
            {'name' => 'dummy_with_package', 'release' => 'dummy2', 'provides_links' => [], 'consumes_links' => [], 'properties' => nil}])
          expect(addon.properties).to eq({'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}})
        end
      end
    end
  end
end

