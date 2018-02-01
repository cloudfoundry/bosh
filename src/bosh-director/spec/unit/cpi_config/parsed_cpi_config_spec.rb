require 'spec_helper'

module Bosh::Director
  module CpiConfig
    describe ParsedCpiConfig do
      let(:cpis) do
        [
          Cpi.parse(
            'name' => 'cpi-name1',
            'type' => 'cpi-type',
            'properties' => {
              'somekey' => 'someproperty',
            },
          ),
          Cpi.parse(
            'name' => 'cpi-name2',
            'type' => 'cpi-type1',
            'properties' => {
              'somekey' => 'someproperty',
            },
          ),
        ]
      end

      subject(:parsed_cpi_config) { described_class.new(cpis) }
      describe '#find_cpi_by_name' do
        it 'returns the cpi with that name' do
          cpi = parsed_cpi_config.find_cpi_by_name('cpi-name2')
          expect(cpi).to eq(cpis[1])
        end
        context 'when using migrated_from cpis' do
          let(:cpis) do
            [
              Cpi.parse(
                'name' => 'cpi-name1',
                'type' => 'cpi-type',
                'properties' => {
                  'somekey' => 'someproperty',
                },
                'migrated_from' => [
                  { 'name' => 'old1' },
                  { 'name' => 'old2' },
                  { 'name' => 'old3' },
                ],
              ),
              Cpi.parse(
                'name' => 'cpi-name2',
                'type' => 'cpi-type1',
                'properties' => {
                  'somekey' => 'someproperty',
                },
                'migrated_from' => [
                  { 'name' => 'old4' },
                  { 'name' => 'old5' },
                  { 'name' => 'old6' },
                ],
              ),
            ]
          end

          it 'can find the cpis by any of their migrated_from names' do
            def finds_correct_cpi(name, cpi)
              found = parsed_cpi_config.find_cpi_by_name(name)
              expect(found).to eq(cpi)
            end

            finds_correct_cpi('old1', cpis[0])
            finds_correct_cpi('old2', cpis[0])
            finds_correct_cpi('old3', cpis[0])
            finds_correct_cpi('old4', cpis[1])
            finds_correct_cpi('old5', cpis[1])
            finds_correct_cpi('old6', cpis[1])
          end
        end
      end
    end
  end
end
