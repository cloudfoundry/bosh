require 'spec_helper'

module Bosh::Director
  module CpiConfig
    describe Cpi do
      subject(:cpi) { Cpi.parse(cpi_hash) }

      describe '#parse' do
        let(:variable_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator)}

        before do
          allow(Bosh::Director::ConfigServer::VariablesInterpolator).to receive(:new).and_return(variable_interpolator)
          allow(variable_interpolator).to receive(:interpolate_cpi_config).with(cpi_hash).and_return(cpi_hash)
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

        context 'when cpi properties have NO variables' do
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
          it 'parses' do
            expect(cpi.name).to eq('cpi-name')
            expect(cpi.type).to eq('cpi-type')
            expect(cpi.exec_path).to eq('cpi-path')
            expect(cpi.properties).to eq(cpi_hash['properties'])
          end
        end

        context 'when cpi properties have absolute variables' do
          let(:cpi_hash) do
            {
                'name' => '((/cpi-name-var))',
                'type' => '((/cpi-type-var))',
                'exec_path' => '((/cpi-exec-path-var))',
                'properties' => {
                    'somekey' => '((/someproperty-var))'
                }
            }
          end

          let(:interpolated_cpi_hash) do
            {
                'name' => 'cpi-name',
                'type' => 'cpi-type',
                'exec_path' => 'cpi-exec-path',
                'properties' => {
                    'somekey' => 'someproperty'
                }
            }
          end

          before do
            allow(variable_interpolator).to receive(:interpolate_cpi_config)
                                                .with(cpi_hash)
                                                .and_return(interpolated_cpi_hash)
          end

          it 'parses interpolated values' do
            expect(cpi.name).to eq('cpi-name')
            expect(cpi.type).to eq('cpi-type')
            expect(cpi.exec_path).to eq('cpi-exec-path')
            expect(cpi.properties['somekey']).to eq('someproperty')
          end
        end

        context 'when cpi properties have relative variables' do
          before do
            allow(variable_interpolator).to receive(:interpolate_cpi_config)
                                                .with(cpi_hash)
                                                .and_raise("Interpolation error occurred")
          end
          let(:cpi_hash) do
            {
                'name' => 'cpi-name',
                'type' => 'cpi-type',
                'exec_path' => 'cpi-exec-path',
                'properties' => {
                    'somekey' => '((someproperty-var))'
                }
            }
          end
          it 'raises error when interpolates values' do
            expect {
              cpi
            }.to raise_error
          end
        end
      end
    end
  end
end
