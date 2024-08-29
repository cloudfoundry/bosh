require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::StemcellUploadsController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      let(:cpi_config) { FactoryBot.create(:models_config_cpi, :with_manifest).raw_manifest }

      before do
        App.new(config)
        basic_authorize 'admin', 'admin'
      end

      context 'when a cpi is missing the stemcell' do
        before do
          FactoryBot.create(:models_stemcell_upload,
            cpi: cpi_config['cpis'][0]['name'],
            name: 'bosh-stemcell',
            version: '1234',
          )
        end

        it 'returns that stemcell is needed' do
          post '/', JSON.generate(stemcell: { name: 'bosh-stemcell', version: '1234' }), 'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)
          expect(body).to eq('needed' => true)
        end
      end

      context 'when a cpi already references an existing stemcell' do
        context 'multiple cpis' do
          before do
            FactoryBot.create(:models_stemcell_upload,
              cpi: cpi_config['cpis'][0]['name'],
              name: 'bosh-stemcell',
              version: '1234',
            )
            FactoryBot.create(:models_stemcell_upload,
              cpi: cpi_config['cpis'][1]['name'],
              name: 'bosh-stemcell',
              version: '1234',
            )
          end

          it 'returns that stemcell is not needed' do
            post '/', JSON.generate(stemcell: { name: 'bosh-stemcell', version: '1234' }), 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(body).to eq('needed' => false)
          end
        end

        context 'a new cpi is migrated from an existing cpi with a stemcell' do
          let(:migrated_from_cpi) do
            {
              'cpis' => [{
                'migrated_from' => ['name' => cpi_config['cpis'][0]['name']],
                'name' => 'new-cpi',
                'type' => 'cpi',
              }],
            }
          end

          before do
            FactoryBot.create(:models_stemcell_upload,
              cpi: cpi_config['cpis'][0]['name'],
              name: 'bosh-stemcell',
              version: '1234',
            )
            FactoryBot.create(:models_config_cpi, content: migrated_from_cpi.to_yaml)
          end

          it 'returns that stemcell is not needed' do
            post '/', JSON.generate(stemcell: { name: 'bosh-stemcell', version: '1234' }), 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(200)

            body = JSON.parse(last_response.body)
            expect(body).to eq('needed' => false)
          end
        end

        context 'a new cpi is migrated from a blank cpi' do
          let(:migrated_from_cpi) do
            {
              'cpis' => [{
                'migrated_from' => ['name' => ''],
                'name' => 'new-cpi',
                'type' => 'cpi',
              }],
            }
          end

          before do
            FactoryBot.create(:models_stemcell_upload,
              cpi: '',
              name: 'bosh-stemcell',
              version: '1234',
            )
            FactoryBot.create(:models_config_cpi, content: migrated_from_cpi.to_yaml)
          end

          it 'returns that stemcell is not needed' do
            post '/', JSON.generate(stemcell: { name: 'bosh-stemcell', version: '1234' }), 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq(200)

            body = JSON.parse(last_response.body)
            expect(body).to eq('needed' => false)
          end
        end
      end

      context 'missing parameters' do
        it 'requires stemcell' do
          post '/', JSON.generate({}), 'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq(400)
        end

        it 'requires name' do
          post '/', JSON.generate(stemcell: { version: '1234' }), 'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq(400)
        end

        it 'requires version' do
          post '/', JSON.generate(stemcell: { name: 'bosh-stemcell' }), 'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq(400)
        end
      end
    end
  end
end
