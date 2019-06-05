require 'spec_helper'

module Bosh::Director
  describe CpiConfig::CpiManifestParser do
    subject(:parser) { described_class.new }
    let(:event_log) { Config.event_log }
    let(:cpi_manifest) { Bosh::Spec::NewDeployments.multi_cpi_config }

    describe '#parse' do
      let(:parsed_cpis) { subject.parse(cpi_manifest) }

      it 'creates a CPI for every entry' do
        expect(parsed_cpis.cpis[0].name).to eq(cpi_manifest['cpis'][0]['name'])
        expect(parsed_cpis.cpis[0].type).to eq(cpi_manifest['cpis'][0]['type'])
        expect(parsed_cpis.cpis[0].properties).to eq(cpi_manifest['cpis'][0]['properties'])

        expect(parsed_cpis.cpis[1].name).to eq(cpi_manifest['cpis'][1]['name'])
        expect(parsed_cpis.cpis[1].type).to eq(cpi_manifest['cpis'][1]['type'])
        expect(parsed_cpis.cpis[1].properties).to eq(cpi_manifest['cpis'][1]['properties'])
      end

      it 'raises CpiDuplicateName if the cpi name is duplicated' do
        cpi_manifest['cpis'][1]['name'] = cpi_manifest['cpis'][0]['name']
        expect { subject.parse(cpi_manifest) }.to raise_error(Bosh::Director::CpiDuplicateName)
      end

      it 'raises CpiDuplicateName if a cpi name also appears in a migrated_from' do
        cpi_manifest['cpis'][1]['migrated_from'] = [{ 'name' => cpi_manifest['cpis'][0]['name'] }]
        expect { subject.parse(cpi_manifest) }.to raise_error(Bosh::Director::CpiDuplicateName)
      end

      it 'raises CpiDuplicateName if a migrated_from name is duplicated' do
        cpi_manifest['cpis'][0]['migrated_from'] = [{ 'name' => 'migratory' }]
        cpi_manifest['cpis'][1]['migrated_from'] = [{ 'name' => 'migratory' }]
        expect { subject.parse(cpi_manifest) }.to raise_error(Bosh::Director::CpiDuplicateName)
      end
    end

    describe '#merge_configs' do
      let(:additional_cpi_config) do
        {
          'cpis' => [
            {
              'name' => 'additional-cpi-name',
              'type' => 'cpi-type',
              'properties' => {
                'some-other-key' => 'some-other-val',
              },
            },
          ],
        }
      end

      context 'when two configs are merged' do
        it 'contains all cpis from both configs' do
          merged_manifest = subject.merge_configs([additional_cpi_config, cpi_manifest])

          expect(merged_manifest['cpis'].size).to eq(3)
          expect(merged_manifest['cpis']).to include(additional_cpi_config['cpis'][0])
          expect(merged_manifest['cpis']).to include(cpi_manifest['cpis'][0])
          expect(merged_manifest['cpis']).to include(cpi_manifest['cpis'][1])
        end
      end

      context 'when passed configs do not contain cpis key' do
        let(:cpi_configs) { [{}] }

        it 'raises' do
          expect do
            subject.merge_configs(cpi_configs)
          end.to raise_error(Bosh::Director::ValidationMissingField)
        end
      end

      context 'when passed configs contains cpis key but its value is not an array' do
        let(:cpi_configs) { [{ 'cpis' => 'foo' }] }

        it 'raises' do
          expect do
            subject.merge_configs(cpi_configs)
          end.to raise_error(Bosh::Director::ValidationInvalidType)
        end
      end

      context 'when two cpis with the same name are merged' do
        it 'contains both cpis' do
          merged_manifest = subject.merge_configs([additional_cpi_config, additional_cpi_config])

          expect(merged_manifest['cpis'].size).to eq(2)
          expect(merged_manifest['cpis']).to match_array([additional_cpi_config['cpis'][0], additional_cpi_config['cpis'][0]])
        end
      end

      context 'when only one cpi config exists' do
        it 'returns exactly this cpi config' do
          merged_manifest = subject.merge_configs([cpi_manifest])

          expect(merged_manifest['cpis'].size).to eq(2)
          expect(merged_manifest['cpis']).to match_array(cpi_manifest['cpis'])
        end
      end

      context 'when passed configs are an empty array' do
        it 'returns also an empty array' do
          merged_manifest = subject.merge_configs([{ 'cpis' => [] }])

          expect(merged_manifest['cpis']).to match_array([])
        end
      end
    end
  end
end
