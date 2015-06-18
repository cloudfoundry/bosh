require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::ResourcesController do
      include Rack::Test::Methods

      let(:temp_dir) { Dir.mktmpdir}
      let(:test_config) do
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
      end

      let(:director_app) { App.new(config) }

      after { FileUtils.rm_rf(temp_dir) }

      let(:existing_resource_id) { director_app.blobstores.blobstore.create('some data') }
      let(:resource_manager) { ResourceManager.new(director_app.blobstores.blobstore) }
      subject(:app) { described_class.new(config, resource_manager) }
      let(:config) { Config.load_hash(test_config) }

      it 'requires auth' do
        get "/#{existing_resource_id}"
        expect(last_response.status).to eq(401)
      end

      it 'sets the date header' do
        get "/#{existing_resource_id}"
        expect(last_response.headers['Date']).not_to be_nil
      end

      context 'when authorized' do
        before(:each) { basic_authorize 'admin', 'admin' }

        it '404 on missing resource' do
          get '/missing_resource'
          expect(last_response.status).to eq(404)
        end

        it 'can fetch resources from blobstore' do
          get "/#{existing_resource_id}"
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('some data')
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

          it 'cleans up temp file after serving it' do
            basic_authorize 'admin', 'admin'
            expect(resource_manager).to receive(:get_resource_path).with('deadbeef').and_return(tmp_file)

            expect(File.exists?(tmp_file)).to be(true)
            get '/deadbeef'
            expect(last_response.body).to eq('some data')
            expect(File.exists?(tmp_file)).to be(false)
          end
        end
      end
    end
  end
end
