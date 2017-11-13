require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ResurrectionController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
      before { basic_authorize 'admin', 'admin' }

      it 'sets the date header' do
        get '/'
        expect(last_response.headers['Date']).not_to be_nil
      end

      describe 'API calls' do
        describe 'resurrection' do
          it 'sets global resurrection to true' do
            put '/', JSON.generate('resurrection_paused' => true), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(Models::DirectorAttribute.first(name: 'resurrection_paused').value).to eq('true')
          end
          it 'sets global resurrection to false' do
            put '/', JSON.generate('resurrection_paused' => false), { 'CONTENT_TYPE' => 'application/json' }
            expect(last_response.status).to eq(200)
            expect(Models::DirectorAttribute.first(name: 'resurrection_paused').value).to eq('false')
          end
        end

      end
    end
  end
end
