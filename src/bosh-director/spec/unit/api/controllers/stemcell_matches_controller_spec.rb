require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::StemcellMatchesController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      let(:cpi_config) { BD::Models::Config.make(:cpi_with_manifest).raw_manifest }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      context 'when a compatible cpi is missing the stemcell' do
        before do
          BD::Models::Stemcell.make(
            cpi: cpi_config['cpis'][0]['name'],
            name: 'bosh-stemcell',
            version: '1234'
          )
        end

        it 'returns stemcells that are missing' do
          post '/', JSON.generate([{'name' => 'bosh-stemcell', 'version' => '1234'}]), { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)
          expect(body).to eq({
            'missing' => [
              {'name' => 'bosh-stemcell', 'version' => '1234'},
            ],
          })
        end
      end

      context 'when a noncompatible cpi is missing the stemcell' do
        before do
          BD::Models::StemcellMatch.make(
            cpi: cpi_config['cpis'][0]['name'],
            name: 'bosh-stemcell',
            version: '1234'
          )
        end

        it 'returns stemcells that are missing' do
          post '/', JSON.generate([{'name' => 'bosh-stemcell', 'version' => '1234'}]), { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)
          expect(body).to eq({
            'missing' => [
              {'name' => 'bosh-stemcell', 'version' => '1234'},
            ],
          })
        end
      end

      context 'when the stemcell does not need to be uploaded to any cpis' do
        before do
          BD::Models::StemcellMatch.make(
            cpi: cpi_config['cpis'][0]['name'],
            name: 'bosh-stemcell',
            version: '1234'
          )
          BD::Models::StemcellMatch.make(
            cpi: cpi_config['cpis'][1]['name'],
            name: 'bosh-stemcell',
            version: '1234'
          )
        end

        it 'returns that no stemcells are missing' do
          post '/', JSON.generate([{'name' => 'bosh-stemcell', 'version' => '1234'}]), { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)
          expect(body).to eq({
            'missing' => [],
          })
        end
      end

      context 'missing parameters' do
        it 'requires name' do
          post '/', JSON.generate([{'version' => '1234'}]), { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(400)
        end

        it 'requires version' do
          post '/', JSON.generate([{'name' => 'bosh-stemcell'}]), { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response.status).to eq(400)
        end
      end
    end
  end
end
