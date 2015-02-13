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

        let(:app) { TestController }

        let!(:temp_dir) { Dir.mktmpdir}

        before do
          blobstore_dir = File.join(temp_dir, 'blobstore')
          FileUtils.mkdir_p(blobstore_dir)

          test_config = Psych.load(spec_asset('test-director-config.yml'))
          test_config['dir'] = temp_dir
          test_config['blobstore'] = {
            'provider' => 'local',
            'options' => {'blobstore_path' => blobstore_dir}
          }
          test_config['snapshots']['enabled'] = true
          Config.configure(test_config)
          @director_app = App.new(Config.load_hash(test_config))
        end

        after do
          FileUtils.rm_rf(temp_dir)
        end

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
          let(:app) { TestNeverAuthenticatingController }

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
