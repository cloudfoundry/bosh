require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ResourcesController do
      include Rack::Test::Methods

      let(:temp_dir) { Dir.mktmpdir }

      let(:director_app) { App.new(config) }

      let(:blobstore) { double('client') }
      let(:resource_manager) { ResourceManager.new(blobstore) }
      subject(:app) { linted_rack_app(described_class.new(config, resource_manager)) }

      let(:config) do
        config = SpecHelper.spec_get_director_config
        config['dir'] = temp_dir
        config['blobstore'] = {
          'provider' => 'davcli',
          'options' => {
            'endpoint' => 'http://127.0.0.1',
            'user' => 'admin',
            'password' => nil,
            'davcli_path' => true,
          }
        }
        Config.load_hash(config)
      end

      it 'requires auth' do
        get '/existing_resource_id'
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        get '/existing_resource_id'
        expect(last_response.headers['Date']).not_to be_nil
      end

      context 'when authorized' do
        before(:each) { basic_authorize 'admin', 'admin' }

        it '404 on missing resource' do
          allow(blobstore).to(receive(:get)).with('missing_resource', anything).and_raise(Bosh::Blobstore::NotFound)
          get '/missing_resource'
          expect(last_response.status).to eq(404)
        end

        it 'uses NGINX X-Accel-Redirect to fetch resources from blobstore' do
          allow(blobstore).to(receive(:get)).with('existing_resource_id', anything)

          get '/existing_resource_id'
          expect(last_response.status).to eq(200)
          expect(last_response.headers).to have_key('X-Accel-Redirect')
          expect(last_response.headers['X-Accel-Redirect']).to match /\/x_accel_files\/.*/
          expect(last_response.body).to eq('')
        end

        context 'when serving resources from temp' do
          let(:resource_manager) { instance_double('Bosh::Director::Api::ResourceManager') }
          let(:tmp_file) { File.join(Dir.tmpdir, "resource-#{SecureRandom.uuid}") }

          before do
            File.open(tmp_file, 'w') do |f|
              f.write('some data')
            end

            FileUtils.touch(tmp_file)
          end

          it 'cleans up old temp files before serving the new one' do
            basic_authorize 'admin', 'admin'
            expect(resource_manager).to receive(:clean_old_tmpfiles).ordered
            expect(resource_manager).to receive(:get_resource_path).ordered.with('deadbeef').and_return(tmp_file)

            get '/deadbeef'
          end
        end
      end
    end
  end
end
