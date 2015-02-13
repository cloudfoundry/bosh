require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    module Controllers
      class TestController < BaseController
        get '/test_route' do
          return 'Success'
        end
      end

      class TestNeverAuthenticatingController < TestController
        def always_authenticated?
          false
        end
      end

      describe BaseController do
        include Rack::Test::Methods

        subject(:app) { TestController }

        let(:temp_dir) { Dir.mktmpdir}
        let(:test_config) { base_config }
        let(:base_config) {
          blobstore_dir = File.join(temp_dir, 'blobstore')
          FileUtils.mkdir_p(blobstore_dir)

          config = Psych.load(spec_asset('test-director-config.yml'))
          config['dir'] = temp_dir
          config['blobstore'] = {
            'provider' => 'local',
            'options' => {'blobstore_path' => blobstore_dir}
          }
          config['snapshots']['enabled'] = true
          config
        }

        before { App.new(Config.load_hash(test_config)) }

        after { FileUtils.rm_rf(temp_dir) }

        it 'sets the date header' do
          get '/'
          expect(last_response.headers['Date']).not_to be_nil
        end

        it 'requires authentication' do
          get '/test_route'
          expect(last_response.status).to eq(401)
        end

        context 'given valid credentials' do
          before { basic_authorize 'admin', 'admin' }

          it 'succeeds' do
            get '/test_route'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('Success')
          end
        end

        context 'given valid credentials' do
          before { basic_authorize 'luke', 'ImYourFather' }

          it 'succeeds' do
            get '/test_route'
            expect(last_response.status).to eq(401)
          end
        end

        context 'when accessing controllers that dont require authorization default' do
          subject(:app) { TestNeverAuthenticatingController }

          it 'requires authentication' do
            get '/test_route'
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('Success')
          end
        end
      end
    end
  end
end
