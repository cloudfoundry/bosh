require 'spec_helper'

module Bosh::Director
  module CpiConfig
    describe Cpi do
      subject(:cpi) { Cpi.parse(cpi_hash) }
      let(:cpi_hash) do
        {
            'name' => 'cpi-name',
            'type' => 'cpi-type',
            'exec_path' => 'cpi-path',
            'properties' => {
                'somekey' => 'someproperty'
            }
        }
      end

      describe '#parse' do
        it 'parses' do
          expect(cpi.name).to eq('cpi-name')
          expect(cpi.type).to eq('cpi-type')
          expect(cpi.exec_path).to eq('cpi-path')
          expect(cpi.properties).to eq(cpi_hash['properties'])
        end

        context 'when cpi hash has no name' do
          let(:cpi_hash) { {'type' => 'cpi-type'} }

          it 'errors' do
            expect { cpi }.to raise_error ValidationMissingField, "Required property 'name' was not specified in object ({\"type\"=>\"cpi-type\"})"
          end
        end

        context 'when cpi hash has no type' do
          let(:cpi_hash) { {'name' => 'cpi-name'} }

          it 'errors' do
            expect { cpi }.to raise_error ValidationMissingField, "Required property 'type' was not specified in object ({\"name\"=>\"cpi-name\"})"
          end
        end

        context 'when cpi hash has no properties' do
          let(:cpi_hash) { {'name' => 'cpi-name', 'type' => 'cpi-type'} }

          it 'parses' do
            expect(cpi.properties).to eq({})
          end
        end

        context 'when cpi hash has no exec_path' do
          let(:cpi_hash) { {'name' => 'cpi-name', 'type' => 'cpi-type'} }

          it 'falls back to a inferred path from type' do
            expect(cpi.exec_path).to eq('/var/vcap/jobs/cpi-type_cpi/bin/cpi')
          end
        end
      end
    end
  end
end
