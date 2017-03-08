require 'spec_helper'

module Bosh::Director
  module CpiConfig
    describe ParsedCpiConfig do
      let(:cpis) {
        [
            Cpi.parse({
                          'name' => 'cpi-name1',
                          'type' => 'cpi-type',
                          'properties' => {
                              'somekey' => 'someproperty'
                          }
                      }),
            Cpi.parse({
                          'name' => 'cpi-name2',
                          'type' => 'cpi-type1',
                          'properties' => {
                              'somekey' => 'someproperty'
                          }
                      })
        ]
      }

      subject(:parsed_cpi_config) { described_class.new(cpis) }
      describe '#find_cpi_by_name' do
        it 'returns the cpi with that name' do
          cpi = parsed_cpi_config.find_cpi_by_name('cpi-name2')
          expect(cpi).to eq(cpis[1])
        end
      end
    end
  end
end
